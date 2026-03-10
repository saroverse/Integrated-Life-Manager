import json
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.event import Event
from app.models.habit import Habit, HabitLog
from app.models.task import Task
from app.schemas.event import EventResponse
from app.schemas.task import TaskResponse

router = APIRouter(prefix="/planner", tags=["planner"])


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


@router.get("/day")
async def get_day(
    date: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    target = datetime.fromisoformat(date).date() if date else datetime.now(timezone.utc).date()
    today = datetime.now(timezone.utc).date()
    target_str = target.isoformat()

    # Tasks due on this date (pending/in_progress)
    tasks_q = select(Task).where(
        Task.due_date == target_str,
        Task.status.in_(["pending", "in_progress"]),
    ).order_by(Task.due_time.asc().nulls_last())
    tasks = (await db.execute(tasks_q)).scalars().all()

    # Overdue tasks (only show when viewing today or future dates)
    overdue = []
    if target >= today:
        overdue_q = select(Task).where(
            Task.due_date < target_str,
            Task.status.in_(["pending", "in_progress"]),
        ).order_by(Task.due_date.asc())
        overdue = (await db.execute(overdue_q)).scalars().all()

    # Habits scheduled for this date
    habits_q = select(Habit).where(Habit.active == 1)
    all_habits = (await db.execute(habits_q)).scalars().all()
    habit_entries = []
    for habit in all_habits:
        if not _is_scheduled_for(habit, target):
            continue
        log_q = select(HabitLog).where(
            HabitLog.habit_id == habit.id, HabitLog.date == target_str
        )
        log = (await db.execute(log_q)).scalar_one_or_none()
        habit_entries.append({
            "id": habit.id,
            "name": habit.name,
            "icon": habit.icon,
            "color": habit.color,
            "category": habit.category,
            "reminder_time": habit.reminder_time,
            "target_count": habit.target_count,
            "completed": bool(log and log.completed),
            "log_id": log.id if log else None,
        })

    # Events overlapping this date
    events_q = select(Event).where(
        Event.start_date <= target_str,
        (Event.end_date >= target_str) | (Event.end_date.is_(None) & (Event.start_date == target_str)),
    ).order_by(Event.start_time.asc().nulls_last())
    events = (await db.execute(events_q)).scalars().all()

    return {
        "date": target_str,
        "tasks": [TaskResponse.model_validate(t) for t in tasks],
        "overdue_tasks": [TaskResponse.model_validate(t) for t in overdue],
        "habits": habit_entries,
        "events": [EventResponse.model_validate(e) for e in events],
    }


@router.get("/week")
async def get_week(
    start: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    today = datetime.now(timezone.utc).date()
    if start:
        week_start = datetime.fromisoformat(start).date()
    else:
        # Default to current week (Monday)
        week_start = today - timedelta(days=today.weekday())

    result = []
    for i in range(7):
        day = week_start + timedelta(days=i)
        day_str = day.isoformat()

        task_count_q = select(Task).where(
            Task.due_date == day_str,
            Task.status.in_(["pending", "in_progress"]),
        )
        tasks_today = (await db.execute(task_count_q)).scalars().all()

        overdue_count_q = select(Task).where(
            Task.due_date < day_str,
            Task.status.in_(["pending", "in_progress"]),
        )
        overdue_today = len((await db.execute(overdue_count_q)).scalars().all()) if day == today else 0

        event_count_q = select(Event).where(
            Event.start_date <= day_str,
            (Event.end_date >= day_str) | (Event.end_date.is_(None) & (Event.start_date == day_str)),
        )
        event_count = len((await db.execute(event_count_q)).scalars().all())

        habits_q = select(Habit).where(Habit.active == 1)
        all_habits = (await db.execute(habits_q)).scalars().all()
        habit_total = 0
        habit_done = 0
        for habit in all_habits:
            if not _is_scheduled_for(habit, day):
                continue
            habit_total += 1
            log_q = select(HabitLog).where(
                HabitLog.habit_id == habit.id,
                HabitLog.date == day_str,
                HabitLog.completed == 1,
            )
            log = (await db.execute(log_q)).scalar_one_or_none()
            if log:
                habit_done += 1

        result.append({
            "date": day_str,
            "task_count": len(tasks_today),
            "overdue_count": overdue_today,
            "event_count": event_count,
            "habit_total": habit_total,
            "habit_done": habit_done,
        })

    return result
