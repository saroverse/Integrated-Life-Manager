import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.reminder import AppSetting, Reminder
from app.schemas.reminder import DeviceTokenRegister, ReminderCreate, ReminderResponse

router = APIRouter(tags=["reminders"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.get("/reminders", response_model=list[ReminderResponse])
async def list_reminders(status: str | None = None, db: AsyncSession = Depends(get_db)):
    q = select(Reminder)
    if status:
        q = q.where(Reminder.status == status)
    q = q.order_by(Reminder.scheduled_at.asc())
    result = await db.execute(q)
    return result.scalars().all()


@router.post("/reminders", response_model=ReminderResponse, status_code=201)
async def create_reminder(data: ReminderCreate, db: AsyncSession = Depends(get_db)):
    reminder = Reminder(id=str(uuid.uuid4()), created_at=_now(), **data.model_dump())
    db.add(reminder)
    await db.commit()
    await db.refresh(reminder)
    return reminder


@router.post("/reminders/{reminder_id}/dismiss", status_code=200)
async def dismiss_reminder(reminder_id: str, db: AsyncSession = Depends(get_db)):
    reminder = await db.get(Reminder, reminder_id)
    if not reminder:
        raise HTTPException(404, "Reminder not found")
    reminder.status = "dismissed"
    await db.commit()
    return {"ok": True}


@router.post("/reminders/{reminder_id}/snooze", status_code=200)
async def snooze_reminder(reminder_id: str, minutes: int = 15, db: AsyncSession = Depends(get_db)):
    from datetime import timedelta
    reminder = await db.get(Reminder, reminder_id)
    if not reminder:
        raise HTTPException(404, "Reminder not found")
    new_time = (datetime.fromisoformat(reminder.scheduled_at) + timedelta(minutes=minutes)).isoformat()
    reminder.scheduled_at = new_time
    reminder.status = "pending"
    await db.commit()
    return {"scheduled_at": new_time}


@router.post("/device/register-token", status_code=200)
async def register_device_token(data: DeviceTokenRegister, db: AsyncSession = Depends(get_db)):
    setting = await db.get(AppSetting, "fcm_device_token")
    now = _now()
    if setting:
        setting.value = data.fcm_token
        setting.updated_at = now
    else:
        db.add(AppSetting(key="fcm_device_token", value=data.fcm_token, updated_at=now))
    await db.commit()
    return {"ok": True}
