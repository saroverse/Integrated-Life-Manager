import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.journal import JournalEntry
from app.schemas.journal import JournalEntryCreate, JournalEntryResponse, JournalEntryUpdate

router = APIRouter(prefix="/journal", tags=["journal"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.get("", response_model=list[JournalEntryResponse])
async def list_entries(
    start: str | None = None,
    end: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    q = select(JournalEntry)
    if start:
        q = q.where(JournalEntry.date >= start)
    if end:
        q = q.where(JournalEntry.date <= end)
    q = q.order_by(JournalEntry.date.desc())
    result = await db.execute(q)
    return result.scalars().all()


@router.get("/today", response_model=JournalEntryResponse | None)
async def get_today_entry(db: AsyncSession = Depends(get_db)):
    today = datetime.now(timezone.utc).date().isoformat()
    q = select(JournalEntry).where(JournalEntry.date == today)
    result = await db.execute(q)
    return result.scalar_one_or_none()


@router.post("", response_model=JournalEntryResponse, status_code=201)
async def create_entry(data: JournalEntryCreate, db: AsyncSession = Depends(get_db)):
    now = _now()
    entry = JournalEntry(id=str(uuid.uuid4()), created_at=now, updated_at=now, **data.model_dump())
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return entry


@router.get("/{entry_id}", response_model=JournalEntryResponse)
async def get_entry(entry_id: str, db: AsyncSession = Depends(get_db)):
    entry = await db.get(JournalEntry, entry_id)
    if not entry:
        raise HTTPException(404, "Entry not found")
    return entry


@router.put("/{entry_id}", response_model=JournalEntryResponse)
async def update_entry(entry_id: str, data: JournalEntryUpdate, db: AsyncSession = Depends(get_db)):
    entry = await db.get(JournalEntry, entry_id)
    if not entry:
        raise HTTPException(404, "Entry not found")
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(entry, field, value)
    entry.updated_at = _now()
    await db.commit()
    await db.refresh(entry)
    return entry


@router.delete("/{entry_id}", status_code=204)
async def delete_entry(entry_id: str, db: AsyncSession = Depends(get_db)):
    entry = await db.get(JournalEntry, entry_id)
    if not entry:
        raise HTTPException(404, "Entry not found")
    await db.delete(entry)
    await db.commit()
