from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import desc, func, select
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


@router.get("/summary")
async def get_screen_time_summary(days: int = 7, db: AsyncSession = Depends(get_db)):
    today = date.today()
    period_start = (today - timedelta(days=days - 1)).isoformat()
    yesterday = (today - timedelta(days=1)).isoformat()
    prev_start = (today - timedelta(days=days * 2 - 1)).isoformat()
    prev_end = (today - timedelta(days=days)).isoformat()

    # Daily totals for chart (current period)
    daily_q = (
        select(ScreenTimeEntry.date, func.sum(ScreenTimeEntry.duration_seconds).label("total_seconds"))
        .where(ScreenTimeEntry.date >= period_start)
        .group_by(ScreenTimeEntry.date)
        .order_by(ScreenTimeEntry.date)
    )
    daily_rows = (await db.execute(daily_q)).all()

    # Previous period avg (for comparison)
    prev_q = (
        select(ScreenTimeEntry.date, func.sum(ScreenTimeEntry.duration_seconds).label("total_seconds"))
        .where(ScreenTimeEntry.date >= prev_start, ScreenTimeEntry.date <= prev_end)
        .group_by(ScreenTimeEntry.date)
    )
    prev_rows = (await db.execute(prev_q)).all()
    prev_avg_s = sum(r.total_seconds for r in prev_rows) / max(len(prev_rows), 1)

    # Today's per-app breakdown
    today_apps_q = (
        select(ScreenTimeEntry)
        .where(ScreenTimeEntry.date == today.isoformat())
        .order_by(ScreenTimeEntry.duration_seconds.desc())
    )
    today_apps = (await db.execute(today_apps_q)).scalars().all()
    today_total_s = sum(a.duration_seconds for a in today_apps)

    # Yesterday total (for daily delta)
    yest_q = select(func.sum(ScreenTimeEntry.duration_seconds)).where(ScreenTimeEntry.date == yesterday)
    yest_total_s = (await db.execute(yest_q)).scalar() or 0

    # Category breakdown for current period
    cat_q = (
        select(ScreenTimeEntry.app_category, func.sum(ScreenTimeEntry.duration_seconds).label("total_seconds"))
        .where(ScreenTimeEntry.date >= period_start)
        .group_by(ScreenTimeEntry.app_category)
        .order_by(desc("total_seconds"))
    )
    cat_rows = (await db.execute(cat_q)).all()

    current_sum = sum(r.total_seconds for r in daily_rows)
    current_avg_s = current_sum / max(len(daily_rows), 1)

    return {
        "period_days": days,
        "current_avg_hours": round(current_avg_s / 3600, 2),
        "previous_avg_hours": round(prev_avg_s / 3600, 2),
        "today": {
            "total_seconds": today_total_s,
            "total_hours": round(today_total_s / 3600, 2),
            "apps": [
                {
                    "app_name": a.app_name,
                    "app_package": a.app_package,
                    "app_category": a.app_category,
                    "duration_seconds": a.duration_seconds,
                    "duration_minutes": round(a.duration_seconds / 60),
                    "launch_count": a.launch_count,
                }
                for a in today_apps
            ],
        },
        "yesterday_hours": round(yest_total_s / 3600, 2),
        "daily": [
            {"date": r.date, "total_seconds": r.total_seconds, "total_hours": round(r.total_seconds / 3600, 2)}
            for r in daily_rows
        ],
        "categories": [
            {
                "name": r.app_category or "other",
                "total_seconds": r.total_seconds,
                "total_hours": round(r.total_seconds / 3600, 2),
            }
            for r in cat_rows
        ],
    }
