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
    return _is_scheduled_for(habit, date.today())


def _is_scheduled_for(habit: Habit, target: date) -> bool:
    if habit.frequency == "daily":
        return True
    if habit.frequency == "weekdays":
        return target.weekday() < 5
    if habit.frequency == "weekly":
        days = json.loads(habit.frequency_days or "[0]")
        return target.weekday() in days
    if habit.frequency_days:
        days = json.loads(habit.frequency_days)
        return target.weekday() in days
    return True


def _calc_streak(logs: list) -> dict:
    """Calculate current streak, longest streak, and total completions from a list of HabitLog."""
    completed_logs = [l for l in logs if l.completed]
    total_completions = len(completed_logs)
    if not completed_logs:
        return {"current_streak": 0, "longest_streak": 0, "total_completions": 0}

    completed_dates = {l.date for l in completed_logs}
    check = date.today()
    current_streak = 0
    while check.isoformat() in completed_dates:
        current_streak += 1
        check -= timedelta(days=1)

    longest_streak = 0
    streak = 0
    prev = None
    for log in sorted(completed_logs, key=lambda l: l.date):
        d = date.fromisoformat(log.date)
        if prev is None or (d - prev).days == 1:
            streak += 1
            longest_streak = max(longest_streak, streak)
        elif (d - prev).days > 1:
            streak = 1
        prev = d

    return {
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "total_completions": total_completions,
    }


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

        # Load all logs to compute streak
        all_logs_q = select(HabitLog).where(HabitLog.habit_id == habit.id)
        all_logs_result = await db.execute(all_logs_q)
        all_logs = all_logs_result.scalars().all()
        streak_data = _calc_streak(all_logs)

        today_habits.append({
            "id": habit.id,
            "name": habit.name,
            "icon": habit.icon,
            "color": habit.color,
            "category": habit.category,
            "target_count": habit.target_count,
            "completed": bool(log and log.completed),
            "log_id": log.id if log else None,
            "current_streak": streak_data["current_streak"],
        })
    return today_habits


@router.get("/stats")
async def get_habits_stats(days: int = 30, db: AsyncSession = Depends(get_db)):
    today = date.today()
    start_date = today - timedelta(days=days - 1)
    today_str = today.isoformat()

    # Load all active habits
    q = select(Habit).where(Habit.active == 1)
    result = await db.execute(q)
    habits = result.scalars().all()

    # Load all logs in the date range for all habits
    start_str = start_date.isoformat()
    logs_q = select(HabitLog).where(HabitLog.date >= start_str, HabitLog.date <= today_str)
    logs_result = await db.execute(logs_q)
    all_logs_in_range = logs_result.scalars().all()

    # Also load all historical logs for streak calculations
    all_logs_q = select(HabitLog)
    all_logs_result = await db.execute(all_logs_q)
    all_historical_logs = all_logs_result.scalars().all()

    # Group logs by habit_id
    logs_by_habit: dict[str, list] = {}
    for log in all_historical_logs:
        logs_by_habit.setdefault(log.habit_id, []).append(log)

    range_logs_by_habit: dict[str, dict[str, bool]] = {}
    for log in all_logs_in_range:
        range_logs_by_habit.setdefault(log.habit_id, {})[log.date] = bool(log.completed)

    # Build per-day totals
    daily_map: dict[str, dict] = {}
    cur = start_date
    while cur <= today:
        daily_map[cur.isoformat()] = {"date": cur.isoformat(), "completed": 0, "scheduled": 0, "rate": 0.0}
        cur += timedelta(days=1)

    habit_stats = []
    today_completed = 0
    today_total = 0
    week_start = today - timedelta(days=6)
    week_scheduled_days = 0
    week_completed_days = 0
    month_start = today - timedelta(days=29)
    month_scheduled_days = 0
    month_completed_days = 0

    for habit in habits:
        all_logs = logs_by_habit.get(habit.id, [])
        streak_data = _calc_streak(all_logs)
        range_log_dates = range_logs_by_habit.get(habit.id, {})

        # Count scheduled days in range and completions
        scheduled_count = 0
        completed_count = 0
        cur = start_date
        while cur <= today:
            scheduled = _is_scheduled_for(habit, cur)
            if scheduled:
                daily_map[cur.isoformat()]["scheduled"] += 1
                scheduled_count += 1
                if range_log_dates.get(cur.isoformat(), False):
                    daily_map[cur.isoformat()]["completed"] += 1
                    completed_count += 1

            # Today stats
            if cur == today and scheduled:
                today_total += 1
                if range_log_dates.get(today_str, False):
                    today_completed += 1

            # Week stats (last 7 days)
            if week_start <= cur <= today and scheduled:
                week_scheduled_days += 1
                if range_log_dates.get(cur.isoformat(), False):
                    week_completed_days += 1

            # Month stats (last 30 days)
            if month_start <= cur <= today and scheduled:
                month_scheduled_days += 1
                if range_log_dates.get(cur.isoformat(), False):
                    month_completed_days += 1

            cur += timedelta(days=1)

        completion_rate = completed_count / scheduled_count if scheduled_count > 0 else 0.0

        habit_stats.append({
            "id": habit.id,
            "name": habit.name,
            "icon": habit.icon,
            "color": habit.color,
            "current_streak": streak_data["current_streak"],
            "longest_streak": streak_data["longest_streak"],
            "total_completions": streak_data["total_completions"],
            "completion_rate": round(completion_rate, 3),
        })

    # Compute daily rates
    for day_data in daily_map.values():
        if day_data["scheduled"] > 0:
            day_data["rate"] = round(day_data["completed"] / day_data["scheduled"], 3)

    week_rate = round(week_completed_days / week_scheduled_days, 3) if week_scheduled_days > 0 else 0.0
    month_rate = round(month_completed_days / month_scheduled_days, 3) if month_scheduled_days > 0 else 0.0

    return {
        "summary": {
            "total_active": len(habits),
            "today_completed": today_completed,
            "today_total": today_total,
            "week_rate": week_rate,
            "month_rate": month_rate,
        },
        "habits": habit_stats,
        "daily_totals": sorted(daily_map.values(), key=lambda d: d["date"]),
    }


@router.get("/{habit_id}/calendar")
async def get_habit_calendar(
    habit_id: str,
    start: str | None = None,
    end: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    habit = await db.get(Habit, habit_id)
    if not habit:
        raise HTTPException(404, "Habit not found")

    today = date.today()
    end_date = date.fromisoformat(end) if end else today
    start_date = date.fromisoformat(start) if start else (today - timedelta(days=89))

    # Load all logs for streak and calendar
    all_logs_q = select(HabitLog).where(HabitLog.habit_id == habit_id)
    all_logs_result = await db.execute(all_logs_q)
    all_logs = all_logs_result.scalars().all()
    streak_data = _calc_streak(all_logs)

    # Build completion map for the range
    logs_in_range = {
        log.date: bool(log.completed)
        for log in all_logs
        if start_date.isoformat() <= log.date <= end_date.isoformat()
    }

    # Build per-day array
    days = []
    weekday_scheduled = [0] * 7
    weekday_completed = [0] * 7
    cur = start_date
    while cur <= end_date:
        scheduled = _is_scheduled_for(habit, cur)
        completed = logs_in_range.get(cur.isoformat(), False) if scheduled else False
        days.append({"date": cur.isoformat(), "scheduled": scheduled, "completed": completed})
        if scheduled:
            wd = cur.weekday()
            weekday_scheduled[wd] += 1
            if completed:
                weekday_completed[wd] += 1
        cur += timedelta(days=1)

    weekday_rates = [
        round(weekday_completed[i] / weekday_scheduled[i], 3) if weekday_scheduled[i] > 0 else 0.0
        for i in range(7)
    ]

    scheduled_total = sum(weekday_scheduled)
    completed_total = sum(weekday_completed)
    completion_rate = round(completed_total / scheduled_total, 3) if scheduled_total > 0 else 0.0

    return {
        "habit": {
            "id": habit.id,
            "name": habit.name,
            "icon": habit.icon,
            "color": habit.color,
            "frequency": habit.frequency,
            "frequency_days": habit.frequency_days,
        },
        "days": days,
        "stats": {
            "current_streak": streak_data["current_streak"],
            "longest_streak": streak_data["longest_streak"],
            "total_completions": streak_data["total_completions"],
            "completion_rate": completion_rate,
            "weekday_rates": weekday_rates,
        },
    }


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

    q = select(HabitLog).where(HabitLog.habit_id == habit_id)
    result = await db.execute(q)
    logs = result.scalars().all()
    streak_data = _calc_streak(logs)

    return StreakResponse(
        habit_id=habit_id,
        current_streak=streak_data["current_streak"],
        longest_streak=streak_data["longest_streak"],
        total_completions=streak_data["total_completions"],
    )
