from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.screen_time import ScreenTimeEntry
from app.schemas.screen_time import ScreenTimeSyncPayload

router = APIRouter(prefix="/screen-time", tags=["screen_time"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.post("/sync", status_code=200)
async def sync_screen_time(payload: ScreenTimeSyncPayload, db: AsyncSession = Depends(get_db)):
    synced_at = _now()
    upserted = 0
    for entry in payload.entries:
        existing_q = select(ScreenTimeEntry).where(
            ScreenTimeEntry.app_package == entry.app_package,
            ScreenTimeEntry.date == entry.date,
        )
        result = await db.execute(existing_q)
        existing = result.scalar_one_or_none()

        if existing:
            existing.duration_seconds = entry.duration_seconds
            existing.launch_count = entry.launch_count
            existing.last_used = entry.last_used
            existing.synced_at = synced_at
        else:
            db.add(ScreenTimeEntry(**entry.model_dump(), synced_at=synced_at))
            upserted += 1

    await db.commit()
    return {"upserted": upserted, "total": len(payload.entries)}


@router.get("/daily")
async def get_daily_screen_time(date: str | None = None, db: AsyncSession = Depends(get_db)):
    if not date:
        date = datetime.now(timezone.utc).date().isoformat()

    q = (
        select(ScreenTimeEntry)
        .where(ScreenTimeEntry.date == date)
        .order_by(ScreenTimeEntry.duration_seconds.desc())
    )
    result = await db.execute(q)
    entries = result.scalars().all()

    total_seconds = sum(e.duration_seconds for e in entries)
    return {
        "date": date,
        "total_seconds": total_seconds,
        "total_hours": round(total_seconds / 3600, 2),
        "apps": [
            {
                "package": e.app_package,
                "name": e.app_name,
                "category": e.app_category,
                "duration_seconds": e.duration_seconds,
                "duration_minutes": round(e.duration_seconds / 60, 1),
                "launch_count": e.launch_count,
            }
            for e in entries
        ],
    }


@router.get("/trends")
async def get_screen_time_trends(
    start: str | None = None,
    end: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    q = select(
        ScreenTimeEntry.date,
        func.sum(ScreenTimeEntry.duration_seconds).label("total_seconds"),
    ).group_by(ScreenTimeEntry.date)
    if start:
        q = q.where(ScreenTimeEntry.date >= start)
    if end:
        q = q.where(ScreenTimeEntry.date <= end)
    q = q.order_by(ScreenTimeEntry.date.asc())
    result = await db.execute(q)
    rows = result.all()
    return [
        {"date": r.date, "total_seconds": r.total_seconds, "total_hours": round(r.total_seconds / 3600, 2)}
        for r in rows
    ]
