import json
import uuid
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.habit import Habit, HabitLog
from app.schemas.habit import (
    HabitCreate,
    HabitLogCreate,
    HabitLogResponse,
    HabitResponse,
    HabitUpdate,
    StreakResponse,
)

router = APIRouter(prefix="/habits", tags=["habits"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _today() -> str:
    return date.today().isoformat()


def _is_scheduled_today(habit: Habit) -> bool:
    if habit.frequency == "daily":
        return True
    if habit.frequency == "weekdays":
        return date.today().weekday() < 5
    if habit.frequency == "weekly":
        days = json.loads(habit.frequency_days or "[0]")
        return date.today().weekday() in days
    if habit.frequency_days:
        days = json.loads(habit.frequency_days)
        return date.today().weekday() in days
    return True


@router.get("", response_model=list[HabitResponse])
async def list_habits(active_only: bool = True, db: AsyncSession = Depends(get_db)):
    q = select(Habit)
    if active_only:
        q = q.where(Habit.active == 1)
    result = await db.execute(q)
    return result.scalars().all()


@router.get("/today", response_model=list[dict])
async def list_today_habits(db: AsyncSession = Depends(get_db)):
    today = _today()
    q = select(Habit).where(Habit.active == 1)
    result = await db.execute(q)
    habits = result.scalars().all()

    today_habits = []
    for habit in habits:
        if not _is_scheduled_today(habit):
            continue
        log_q = select(HabitLog).where(HabitLog.habit_id == habit.id, HabitLog.date == today)
        log_result = await db.execute(log_q)
        log = log_result.scalar_one_or_none()
        today_habits.append({
            "id": habit.id,
            "name": habit.name,
            "icon": habit.icon,
            "color": habit.color,
            "category": habit.category,
            "target_count": habit.target_count,
            "completed": bool(log and log.completed),
            "log_id": log.id if log else None,
        })
    return today_habits


@router.post("", response_model=HabitResponse, status_code=201)
async def create_habit(data: HabitCreate, db: AsyncSession = Depends(get_db)):
    habit = Habit(id=str(uuid.uuid4()), created_at=_now(), **data.model_dump())
    db.add(habit)
    await db.commit()
    await db.refresh(habit)
    return habit


@router.get("/{habit_id}", response_model=HabitResponse)
async def get_habit(habit_id: str, db: AsyncSession = Depends(get_db)):
    habit = await db.get(Habit, habit_id)
    if not habit:
        raise HTTPException(404, "Habit not found")
    return habit


@router.put("/{habit_id}", response_model=HabitResponse)
async def update_habit(habit_id: str, data: HabitUpdate, db: AsyncSession = Depends(get_db)):
    habit = await db.get(Habit, habit_id)
    if not habit:
        raise HTTPException(404, "Habit not found")
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(habit, field, value)
    await db.commit()
    await db.refresh(habit)
    return habit


@router.delete("/{habit_id}", status_code=204)
async def delete_habit(habit_id: str, db: AsyncSession = Depends(get_db)):
    habit = await db.get(Habit, habit_id)
    if not habit:
        raise HTTPException(404, "Habit not found")
    habit.active = 0
    habit.archived_at = _now()
    await db.commit()


@router.post("/{habit_id}/log", response_model=HabitLogResponse, status_code=201)
async def log_habit(habit_id: str, data: HabitLogCreate, db: AsyncSession = Depends(get_db)):
    habit = await db.get(Habit, habit_id)
    if not habit:
        raise HTTPException(404, "Habit not found")

    # Upsert: if log for this date exists, update it
    q = select(HabitLog).where(HabitLog.habit_id == habit_id, HabitLog.date == data.date)
    result = await db.execute(q)
    existing = result.scalar_one_or_none()

    if existing:
        existing.completed = data.completed
        existing.count = data.count
        existing.note = data.note
        existing.logged_at = _now()
        await db.commit()
        await db.refresh(existing)
        return existing

    log = HabitLog(
        id=str(uuid.uuid4()),
        habit_id=habit_id,
        logged_at=_now(),
        **data.model_dump(),
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log


@router.get("/{habit_id}/logs", response_model=list[HabitLogResponse])
async def get_habit_logs(
    habit_id: str,
    start: str | None = None,
    end: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    q = select(HabitLog).where(HabitLog.habit_id == habit_id)
    if start:
        q = q.where(HabitLog.date >= start)
    if end:
        q = q.where(HabitLog.date <= end)
    q = q.order_by(HabitLog.date.desc())
    result = await db.execute(q)
    return result.scalars().all()


@router.get("/{habit_id}/streak", response_model=StreakResponse)
async def get_habit_streak(habit_id: str, db: AsyncSession = Depends(get_db)):
    habit = await db.get(Habit, habit_id)
    if not habit:
        raise HTTPException(404, "Habit not found")

    q = select(HabitLog).where(
        HabitLog.habit_id == habit_id, HabitLog.completed == 1
    ).order_by(HabitLog.date.desc())
    result = await db.execute(q)
    logs = result.scalars().all()

    total_completions = len(logs)
    if not logs:
        return StreakResponse(habit_id=habit_id, current_streak=0, longest_streak=0, total_completions=0)

    completed_dates = {log.date for log in logs}
    check = date.today()
    current_streak = 0
    while check.isoformat() in completed_dates:
        current_streak += 1
        check -= timedelta(days=1)

    longest_streak = 0
    streak = 0
    prev: date | None = None
    for log in sorted(logs, key=lambda l: l.date):
        d = date.fromisoformat(log.date)
        if prev is None or (d - prev).days == 1:
            streak += 1
            longest_streak = max(longest_streak, streak)
        elif (d - prev).days > 1:
            streak = 1
        prev = d

    return StreakResponse(
        habit_id=habit_id,
        current_streak=current_streak,
        longest_streak=longest_streak,
        total_completions=total_completions,
    )
