from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.habit import Habit, HabitLog
from app.models.health import HealthMetric, SleepSession
from app.models.screen_time import ScreenTimeEntry
from app.models.summary import Summary
from app.models.task import Task

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/today")
async def get_today_dashboard(db: AsyncSession = Depends(get_db)):
    today = date.today().isoformat()
    yesterday = (date.today() - timedelta(days=1)).isoformat()

    # Tasks due today
    tasks_q = select(Task).where(
        Task.due_date <= today,
        Task.status.in_(["pending", "in_progress"]),
    ).order_by(Task.priority.desc())
    tasks_result = await db.execute(tasks_q)
    tasks_today = tasks_result.scalars().all()

    # Completed today
    done_q = select(func.count(Task.id)).where(
        Task.completed_at >= today,
        Task.status == "done",
    )
    tasks_done_today = (await db.execute(done_q)).scalar() or 0

    # Habits today
    habits_q = select(Habit).where(Habit.active == 1)
    habits_result = await db.execute(habits_q)
    habits = habits_result.scalars().all()

    habit_data = []
    for habit in habits:
        log_q = select(HabitLog).where(HabitLog.habit_id == habit.id, HabitLog.date == today)
        log = (await db.execute(log_q)).scalar_one_or_none()
        habit_data.append({
            "id": habit.id,
            "name": habit.name,
            "icon": habit.icon,
            "color": habit.color,
            "completed": bool(log and log.completed),
        })
    habits_done = sum(1 for h in habit_data if h["completed"])

    # Health today
    steps_q = select(func.sum(HealthMetric.value)).where(
        HealthMetric.metric_type == "steps", HealthMetric.date == today
    )
    steps_today = (await db.execute(steps_q)).scalar() or 0

    sleep_q = select(SleepSession).where(SleepSession.date == today)
    sleep_today = (await db.execute(sleep_q)).scalar_one_or_none()

    # Screen time today
    screen_q = select(func.sum(ScreenTimeEntry.duration_seconds)).where(
        ScreenTimeEntry.date == today
    )
    screen_today_s = (await db.execute(screen_q)).scalar() or 0

    # Latest briefing
    briefing_q = select(Summary).where(
        Summary.summary_type == "daily_briefing",
        Summary.status == "ready",
    ).order_by(Summary.created_at.desc())
    briefing = (await db.execute(briefing_q)).scalar_one_or_none()

    return {
        "date": today,
        "tasks": {
            "due_today": [{"id": t.id, "title": t.title, "priority": t.priority} for t in tasks_today],
            "completed_today": tasks_done_today,
        },
        "habits": {
            "today": habit_data,
            "completed": habits_done,
            "total": len(habit_data),
        },
        "health": {
            "steps": int(steps_today),
            "sleep": {
                "total": sleep_today.total_duration,
                "score": sleep_today.sleep_score,
            } if sleep_today else None,
        },
        "screen_time": {
            "total_hours": round(screen_today_s / 3600, 1),
        },
        "latest_briefing": {
            "id": briefing.id if briefing else None,
            "content": (briefing.content[:500] + "..." if len(briefing.content) > 500 else briefing.content) if briefing else None,
            "created_at": briefing.created_at if briefing else None,
        },
    }


@router.get("/stats")
async def get_stats(db: AsyncSession = Depends(get_db)):
    today = date.today().isoformat()
    week_ago = (date.today() - timedelta(days=7)).isoformat()
    month_ago = (date.today() - timedelta(days=30)).isoformat()

    # Task completion rate last 7 days
    tasks_done_q = select(func.count(Task.id)).where(
        Task.completed_at >= week_ago, Task.status == "done"
    )
    tasks_done_7 = (await db.execute(tasks_done_q)).scalar() or 0

    # Habit completion last 7 days
    habit_logs_q = select(func.count(HabitLog.id)).where(
        HabitLog.date >= week_ago, HabitLog.completed == 1
    )
    habit_completions_7 = (await db.execute(habit_logs_q)).scalar() or 0

    # Avg steps last 7 days
    avg_steps_q = select(func.avg(HealthMetric.value)).where(
        HealthMetric.metric_type == "steps",
        HealthMetric.date >= week_ago,
    )
    avg_steps_7 = (await db.execute(avg_steps_q)).scalar() or 0

    # Avg screen time last 7 days
    avg_screen_q = select(
        func.sum(ScreenTimeEntry.duration_seconds) / 7.0
    ).where(ScreenTimeEntry.date >= week_ago)
    avg_screen_7 = (await db.execute(avg_screen_q)).scalar() or 0

    return {
        "last_7_days": {
            "tasks_completed": tasks_done_7,
            "habit_completions": habit_completions_7,
            "avg_daily_steps": round(avg_steps_7),
            "avg_daily_screen_hours": round(avg_screen_7 / 3600, 1),
        }
    }
