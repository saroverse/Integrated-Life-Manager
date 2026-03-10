import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.event import Event
from app.schemas.event import EventCreate, EventResponse, EventUpdate

router = APIRouter(prefix="/events", tags=["events"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.get("", response_model=list[EventResponse])
async def list_events(
    start: str | None = None,
    end: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    q = select(Event).order_by(Event.start_date.asc(), Event.start_time.asc().nulls_last())
    if start:
        q = q.where(Event.start_date >= start)
    if end:
        q = q.where(Event.start_date <= end)
    result = await db.execute(q)
    return result.scalars().all()


@router.post("", response_model=EventResponse, status_code=201)
async def create_event(data: EventCreate, db: AsyncSession = Depends(get_db)):
    now = _now()
    event = Event(id=str(uuid.uuid4()), created_at=now, updated_at=now, **data.model_dump())
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return event


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(event_id: str, db: AsyncSession = Depends(get_db)):
    event = await db.get(Event, event_id)
    if not event:
        raise HTTPException(404, "Event not found")
    return event


@router.put("/{event_id}", response_model=EventResponse)
async def update_event(event_id: str, data: EventUpdate, db: AsyncSession = Depends(get_db)):
    event = await db.get(Event, event_id)
    if not event:
        raise HTTPException(404, "Event not found")
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(event, field, value)
    event.updated_at = _now()
    await db.commit()
    await db.refresh(event)
    return event


@router.delete("/{event_id}", status_code=204)
async def delete_event(event_id: str, db: AsyncSession = Depends(get_db)):
    event = await db.get(Event, event_id)
    if not event:
        raise HTTPException(404, "Event not found")
    await db.delete(event)
    await db.commit()
