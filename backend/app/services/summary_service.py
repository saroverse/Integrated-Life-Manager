import time
import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.habit import Habit, HabitLog
from app.models.health import HealthMetric, SleepSession
from app.models.journal import JournalEntry
from app.models.reminder import AppSetting
from app.models.screen_time import ScreenTimeEntry
from app.models.summary import Summary
from app.models.task import Task
from app.services.ai_service import generate_text
from app.services.notification_service import send_push

SYSTEM_DAILY_RECAP = """You are a personal life assistant helping someone review their day.
Be direct, warm, and insightful. Use markdown formatting with headers.
Focus on patterns, wins, and actionable observations.
Keep it under 450 words. Be specific, not generic."""

SYSTEM_DAILY_BRIEFING = """You are a personal life assistant helping someone prepare for their day.
Be energizing, focused, and practical. Use markdown formatting with headers.
Prioritize ruthlessly — help them focus on what matters most.
Keep it under 400 words. Be specific and motivating."""

SYSTEM_WEEKLY_RECAP = """You are a personal life assistant helping someone review their week.
Identify meaningful patterns across the 7 days. Use markdown formatting.
Be analytical but warm. Highlight what's working and what needs attention.
Keep it under 600 words."""

SYSTEM_WEEKLY_BRIEFING = """You are a personal life assistant helping someone prepare for their week.
Help them set priorities and anticipate challenges. Use markdown formatting.
Be strategic and encouraging. Keep it under 500 words."""

SYSTEM_MONTHLY_RECAP = """You are a personal life assistant helping someone review their month.
Identify long-term trends and meaningful progress. Use markdown formatting.
Be reflective and growth-oriented. Keep it under 700 words."""

SYSTEM_MONTHLY_BRIEFING = """You are a personal life assistant helping someone prepare for their month.
Help them set meaningful intentions and priorities. Use markdown formatting.
Be inspiring and strategic. Keep it under 600 words."""


async def _get_fcm_token(db: AsyncSession) -> str | None:
    setting = await db.get(AppSetting, "fcm_device_token")
    return setting.value if setting else None


async def _get_tasks_for_date(db: AsyncSession, target_date: str) -> dict:
    done_q = select(Task).where(Task.completed_at >= target_date, Task.completed_at < target_date + "Z")
    done_result = await db.execute(done_q)
    completed = done_result.scalars().all()

    pending_q = select(Task).where(
        Task.due_date == target_date,
        Task.status.in_(["pending", "in_progress"]),
    )
    pending_result = await db.execute(pending_q)
    pending = pending_result.scalars().all()

    overdue_q = select(Task).where(
        Task.due_date < target_date,
        Task.status.in_(["pending", "in_progress"]),
    )
    overdue_result = await db.execute(overdue_q)
    overdue = overdue_result.scalars().all()

    return {
        "completed": [{"title": t.title, "priority": t.priority} for t in completed],
        "pending": [{"title": t.title, "priority": t.priority, "due": t.due_date} for t in pending],
        "overdue": [{"title": t.title, "priority": t.priority, "due": t.due_date} for t in overdue],
    }


async def _get_habits_for_date(db: AsyncSession, target_date: str) -> dict:
    habits_q = select(Habit).where(Habit.active == 1)
    habits_result = await db.execute(habits_q)
    habits = habits_result.scalars().all()

    habit_info = []
    for habit in habits:
        log_q = select(HabitLog).where(HabitLog.habit_id == habit.id, HabitLog.date == target_date)
        log_result = await db.execute(log_q)
        log = log_result.scalar_one_or_none()
        habit_info.append({"name": habit.name, "category": habit.category, "completed": bool(log and log.completed)})

    completed = [h for h in habit_info if h["completed"]]
    missed = [h for h in habit_info if not h["completed"]]
    return {"total": len(habit_info), "completed": completed, "missed": missed}


async def _get_health_for_date(db: AsyncSession, target_date: str) -> dict:
    health = {}
    steps_q = select(func.sum(HealthMetric.value)).where(
        HealthMetric.metric_type == "steps", HealthMetric.date == target_date
    )
    health["steps"] = (await db.execute(steps_q)).scalar() or 0

    for metric in ["resting_heart_rate", "heart_rate_variability_sdnn"]:
        q = select(func.avg(HealthMetric.value)).where(
            HealthMetric.metric_type == metric, HealthMetric.date == target_date
        )
        val = (await db.execute(q)).scalar()
        health[metric] = round(val, 1) if val else None

    sleep_q = select(SleepSession).where(SleepSession.date == target_date)
    sleep = (await db.execute(sleep_q)).scalar_one_or_none()
    health["sleep"] = {
        "total": sleep.total_duration,
        "deep": sleep.deep_sleep,
        "rem": sleep.rem_sleep,
        "score": sleep.sleep_score,
    } if sleep else None

    return health


async def _get_screen_time_for_date(db: AsyncSession, target_date: str) -> dict:
    q = select(ScreenTimeEntry).where(ScreenTimeEntry.date == target_date).order_by(
        ScreenTimeEntry.duration_seconds.desc()
    )
    result = await db.execute(q)
    entries = result.scalars().all()
    total_seconds = sum(e.duration_seconds for e in entries)
    top_apps = [
        {"name": e.app_name, "minutes": round(e.duration_seconds / 60, 0)}
        for e in entries[:5]
    ]
    return {"total_hours": round(total_seconds / 3600, 1), "top_apps": top_apps}


def _format_tasks(tasks: dict) -> str:
    lines = []
    lines.append(f"Completed ({len(tasks['completed'])}): " + ", ".join(t['title'] for t in tasks['completed'][:5]) or "none")
    lines.append(f"Pending ({len(tasks['pending'])}): " + ", ".join(t['title'] for t in tasks['pending'][:5]) or "none")
    if tasks['overdue']:
        lines.append(f"Overdue ({len(tasks['overdue'])}): " + ", ".join(t['title'] for t in tasks['overdue'][:5]))
    return "\n".join(lines)


def _format_habits(habits: dict) -> str:
    done = ", ".join(h['name'] for h in habits['completed']) or "none"
    missed = ", ".join(h['name'] for h in habits['missed']) or "none"
    pct = round(len(habits['completed']) / habits['total'] * 100) if habits['total'] else 0
    return f"Done ({pct}%): {done}\nMissed: {missed}"


def _format_health(health: dict) -> str:
    lines = [f"Steps: {int(health.get('steps', 0)):,}"]
    if health.get("resting_heart_rate"):
        lines.append(f"Resting HR: {health['resting_heart_rate']} bpm")
    if health.get("heart_rate_variability_sdnn"):
        lines.append(f"HRV: {health['heart_rate_variability_sdnn']} ms")
    sleep = health.get("sleep")
    if sleep and sleep.get("total"):
        lines.append(f"Sleep: {sleep['total']:.1f}h total" +
                     (f", {sleep['deep']:.1f}h deep" if sleep.get('deep') else "") +
                     (f", {sleep['rem']:.1f}h REM" if sleep.get('rem') else "") +
                     (f" (score: {sleep['score']})" if sleep.get('score') else ""))
    return "\n".join(lines) if lines else "No health data recorded"


async def generate_daily_recap(db: AsyncSession, target_date: str | None = None) -> Summary:
    if not target_date:
        target_date = date.today().isoformat()

    tasks = await _get_tasks_for_date(db, target_date)
    habits = await _get_habits_for_date(db, target_date)
    health = await _get_health_for_date(db, target_date)
    screen = await _get_screen_time_for_date(db, target_date)

    journal_q = select(JournalEntry).where(JournalEntry.date == target_date)
    journal = (await db.execute(journal_q)).scalar_one_or_none()

    prompt = f"""Date: {target_date}

TASKS:
{_format_tasks(tasks)}

HABITS:
{_format_habits(habits)}

HEALTH:
{_format_health(health)}

SCREEN TIME:
Total: {screen['total_hours']}h
Top apps: {', '.join(f"{a['name']} ({a['minutes']:.0f}m)" for a in screen['top_apps'])}

{f"JOURNAL NOTE: {journal.content[:300]}" if journal else ""}

Please provide a daily recap with:
1. **Today's Wins** — what went well
2. **What Was Left Undone** — incomplete tasks/habits and their potential impact
3. **Health Snapshot** — brief interpretation of today's numbers
4. **One Insight for Tomorrow** — one specific, actionable suggestion"""

    start = time.time()
    content, model_used = await generate_text(prompt, SYSTEM_DAILY_RECAP)
    gen_time = time.time() - start

    summary = Summary(
        id=str(uuid.uuid4()),
        summary_type="daily_recap",
        period_start=target_date,
        period_end=target_date,
        content=content,
        model_used=model_used,
        generation_time=gen_time,
        status="ready",
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(summary)
    await db.commit()
    await db.refresh(summary)

    token = await _get_fcm_token(db)
    await send_push("Day in Review", "Your evening recap is ready.", token, {"type": "daily_recap", "id": summary.id})

    return summary


async def generate_daily_briefing(db: AsyncSession, target_date: str | None = None) -> Summary:
    if not target_date:
        target_date = date.today().isoformat()

    tasks = await _get_tasks_for_date(db, target_date)
    habits = await _get_habits_for_date(db, target_date)

    yesterday = (date.fromisoformat(target_date) - timedelta(days=1)).isoformat()
    health_yesterday = await _get_health_for_date(db, yesterday)
    screen_yesterday = await _get_screen_time_for_date(db, yesterday)

    # 3-day HRV trend for recovery signal
    hrv_values = []
    for i in range(3):
        d = (date.fromisoformat(target_date) - timedelta(days=i)).isoformat()
        q = select(func.avg(HealthMetric.value)).where(
            HealthMetric.metric_type == "heart_rate_variability_sdnn",
            HealthMetric.date == d,
        )
        val = (await db.execute(q)).scalar()
        if val:
            hrv_values.append(val)

    hrv_trend = ""
    if len(hrv_values) >= 2:
        if hrv_values[0] > hrv_values[-1]:
            hrv_trend = f"HRV trending up ({hrv_values[0]:.0f} ms) — good recovery"
        else:
            hrv_trend = f"HRV trending down ({hrv_values[0]:.0f} ms) — consider lighter day"

    prompt = f"""Date: {target_date}

TASKS TODAY:
Due today ({len(tasks['pending'])}): {', '.join(t['title'] for t in tasks['pending'][:5]) or 'none'}
Overdue ({len(tasks['overdue'])}): {', '.join(t['title'] for t in tasks['overdue'][:3]) or 'none'}

HABITS TODAY:
{', '.join(h['name'] for h in habits['completed'] + habits['missed'][:5]) or 'no habits set'}

HEALTH CONTEXT (yesterday):
{_format_health(health_yesterday)}
{hrv_trend}

SCREEN TIME YESTERDAY: {screen_yesterday['total_hours']}h

Please provide a morning briefing with:
1. **Today's Top Priorities** — max 3 things that matter most today
2. **Energy & Recovery Note** — based on sleep and HRV data
3. **Watch Out This Week** — any upcoming deadlines or patterns to be aware of
4. **Today's Intention** — one motivating nudge based on current habits/streaks"""

    start = time.time()
    content, model_used = await generate_text(prompt, SYSTEM_DAILY_BRIEFING)
    gen_time = time.time() - start

    summary = Summary(
        id=str(uuid.uuid4()),
        summary_type="daily_briefing",
        period_start=target_date,
        period_end=target_date,
        content=content,
        model_used=model_used,
        generation_time=gen_time,
        status="ready",
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(summary)
    await db.commit()
    await db.refresh(summary)

    body_lines = [ln.strip("# ").strip() for ln in content.splitlines() if ln.strip()]
    push_body = body_lines[0][:100] if body_lines else "Your morning briefing is ready."
    token = await _get_fcm_token(db)
    await send_push("Good morning", push_body, token, {"type": "daily_briefing", "id": summary.id})

    return summary


async def generate_weekly_recap(db: AsyncSession, week_start: str | None = None) -> Summary:
    if not week_start:
        today = date.today()
        week_start = (today - timedelta(days=today.weekday())).isoformat()
    week_end = (date.fromisoformat(week_start) + timedelta(days=6)).isoformat()

    # Aggregate 7-day data
    days_data: list[dict[str, Any]] = []
    for i in range(7):
        d = (date.fromisoformat(week_start) + timedelta(days=i)).isoformat()
        tasks = await _get_tasks_for_date(db, d)
        habits = await _get_habits_for_date(db, d)
        health = await _get_health_for_date(db, d)
        screen = await _get_screen_time_for_date(db, d)
        days_data.append({"date": d, "tasks": tasks, "habits": habits, "health": health, "screen": screen})

    avg_steps = sum(row["health"].get("steps", 0) for row in days_data) / 7
    avg_sleep = [
        row["health"]["sleep"]["total"]
        for row in days_data
        if row["health"].get("sleep") and row["health"]["sleep"].get("total")
    ]
    avg_screen = sum(row["screen"]["total_hours"] for row in days_data) / 7
    habit_completion = sum(len(row["habits"]["completed"]) for row in days_data)
    habit_total = sum(row["habits"]["total"] for row in days_data)
    task_completion = sum(len(row["tasks"]["completed"]) for row in days_data)

    prompt = f"""Week: {week_start} to {week_end}

TASK SUMMARY:
Total completed this week: {task_completion}

HABIT SUMMARY:
Overall completion: {habit_completion}/{habit_total} ({round(habit_completion/habit_total*100) if habit_total else 0}%)

HEALTH AVERAGES:
Average steps/day: {avg_steps:,.0f}
Average sleep: {sum(avg_sleep)/len(avg_sleep):.1f}h (when recorded)
Average screen time: {avg_screen:.1f}h/day

Please provide a weekly recap with:
1. **Week in Review** — overall tone and achievement level
2. **Habit Patterns** — what habits were strong vs inconsistent
3. **Health Trends** — how the body held up this week
4. **Screen Time Reflection** — what the phone usage says about focus
5. **Key Lesson** — one meaningful insight from this week to carry forward"""

    start = time.time()
    content, model_used = await generate_text(prompt, SYSTEM_WEEKLY_RECAP)
    gen_time = time.time() - start

    summary = Summary(
        id=str(uuid.uuid4()),
        summary_type="weekly_recap",
        period_start=week_start,
        period_end=week_end,
        content=content,
        model_used=model_used,
        generation_time=gen_time,
        status="ready",
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(summary)
    await db.commit()
    await db.refresh(summary)
    return summary


async def generate_weekly_briefing(db: AsyncSession, week_start: str | None = None) -> Summary:
    """Forward-looking: what's ahead this week."""
    if not week_start:
        today = date.today()
        week_start = (today - timedelta(days=today.weekday())).isoformat()
    week_end = (date.fromisoformat(week_start) + timedelta(days=6)).isoformat()

    # Tasks due this week (pending/overdue)
    tasks_q = select(Task).where(
        Task.due_date >= week_start,
        Task.due_date <= week_end,
        Task.status.in_(["pending", "in_progress"]),
    ).order_by(Task.priority.desc())
    upcoming_tasks = (await db.execute(tasks_q)).scalars().all()

    overdue_q = select(Task).where(
        Task.due_date < week_start,
        Task.status.in_(["pending", "in_progress"]),
    )
    overdue_tasks = (await db.execute(overdue_q)).scalars().all()

    # Active habits
    habits_q = select(Habit).where(Habit.active == 1)
    habits = (await db.execute(habits_q)).scalars().all()

    # Last 7 days of health for trend context
    prev_week_start = (date.fromisoformat(week_start) - timedelta(days=7)).isoformat()
    avg_steps_q = select(func.avg(HealthMetric.value)).where(
        HealthMetric.metric_type == "steps",
        HealthMetric.date >= prev_week_start,
        HealthMetric.date < week_start,
    )
    avg_steps = (await db.execute(avg_steps_q)).scalar() or 0

    avg_sleep_q = select(func.avg(SleepSession.total_duration)).where(
        SleepSession.date >= prev_week_start,
        SleepSession.date < week_start,
    )
    avg_sleep = (await db.execute(avg_sleep_q)).scalar()

    # HRV trend (last 3 days)
    hrv_values = []
    for i in range(3):
        d = (date.fromisoformat(week_start) - timedelta(days=i + 1)).isoformat()
        q = select(func.avg(HealthMetric.value)).where(
            HealthMetric.metric_type == "heart_rate_variability_sdnn",
            HealthMetric.date == d,
        )
        val = (await db.execute(q)).scalar()
        if val:
            hrv_values.append(val)
    hrv_note = ""
    if hrv_values:
        hrv_avg = sum(hrv_values) / len(hrv_values)
        if hrv_avg < 30:
            hrv_note = f"HRV averaging {hrv_avg:.0f} ms — recovery may be compromised, consider lighter intensity days"
        else:
            hrv_note = f"HRV averaging {hrv_avg:.0f} ms — recovery looks adequate"

    prompt = f"""Week ahead: {week_start} to {week_end}

TASKS DUE THIS WEEK ({len(upcoming_tasks)}):
{chr(10).join(f"- [{t.priority}] {t.title} (due {t.due_date})" for t in upcoming_tasks[:8]) or "No tasks due this week"}

OVERDUE ({len(overdue_tasks)}):
{chr(10).join(f"- {t.title}" for t in overdue_tasks[:5]) or "None"}

ACTIVE HABITS TO MAINTAIN ({len(habits)}):
{", ".join(h.name for h in habits) or "No active habits"}

LAST WEEK'S HEALTH BASELINE:
Average daily steps: {avg_steps:,.0f}
Average sleep: {f"{avg_sleep:.1f}h" if avg_sleep else "insufficient data"}
{hrv_note}

Please provide a weekly briefing with:
1. **This Week's Mission** — the 2-3 things that will make this week a success
2. **Task Battle Plan** — which tasks to tackle first, grouped by priority
3. **Habits to Protect** — which habits are most important to maintain this week and why
4. **Body & Energy Strategy** — based on last week's health data, how to manage energy
5. **Watch Out For** — potential obstacles or scheduling conflicts to anticipate"""

    start = time.time()
    content, model_used = await generate_text(prompt, SYSTEM_WEEKLY_BRIEFING)
    gen_time = time.time() - start

    summary = Summary(
        id=str(uuid.uuid4()),
        summary_type="weekly_briefing",
        period_start=week_start,
        period_end=week_end,
        content=content,
        model_used=model_used,
        generation_time=gen_time,
        status="ready",
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(summary)
    await db.commit()
    await db.refresh(summary)
    return summary


async def generate_monthly_recap(db: AsyncSession, month_start: str | None = None) -> Summary:
    if not month_start:
        today = date.today()
        month_start = today.replace(day=1).isoformat()

    from calendar import monthrange
    d = date.fromisoformat(month_start)
    last_day = monthrange(d.year, d.month)[1]
    month_end = d.replace(day=last_day).isoformat()

    # Aggregate monthly health averages
    steps_q = select(func.avg(HealthMetric.value)).where(
        HealthMetric.metric_type == "steps",
        HealthMetric.date >= month_start,
        HealthMetric.date <= month_end,
    )
    avg_steps = (await db.execute(steps_q)).scalar() or 0

    sleep_q = select(func.avg(SleepSession.total_duration)).where(
        SleepSession.date >= month_start,
        SleepSession.date <= month_end,
    )
    avg_sleep = (await db.execute(sleep_q)).scalar()

    screen_q = select(func.avg(ScreenTimeEntry.duration_seconds)).where(
        ScreenTimeEntry.date >= month_start,
        ScreenTimeEntry.date <= month_end,
    )
    avg_screen_s = (await db.execute(screen_q)).scalar() or 0

    # Task throughput
    tasks_done_q = select(func.count(Task.id)).where(
        Task.completed_at >= month_start,
        Task.status == "done",
    )
    tasks_done = (await db.execute(tasks_done_q)).scalar() or 0

    # Journal mood average
    mood_q = select(func.avg(JournalEntry.mood)).where(
        JournalEntry.date >= month_start,
        JournalEntry.mood.isnot(None),
    )
    avg_mood = (await db.execute(mood_q)).scalar()

    prompt = f"""Month: {month_start} to {month_end}

TASK THROUGHPUT:
Tasks completed this month: {tasks_done}

HEALTH AVERAGES:
Daily steps: {avg_steps:,.0f}
Nightly sleep: {f"{avg_sleep:.1f}h" if avg_sleep else "insufficient data"}
Daily screen time: {round(avg_screen_s/3600, 1)}h

{f"JOURNAL: Average mood score: {avg_mood:.1f}/10" if avg_mood else ""}

Please provide a monthly recap with:
1. **Month Overview** — overall theme and accomplishment level
2. **Habit Consistency** — which habits built momentum vs stalled
3. **Health Journey** — physical trends over the month
4. **Focus & Distraction** — what the screen time patterns reveal
5. **Growth Areas** — 2-3 specific areas where you've genuinely progressed
6. **Into Next Month** — one key priority to carry forward"""

    start = time.time()
    content, model_used = await generate_text(prompt, SYSTEM_MONTHLY_RECAP)
    gen_time = time.time() - start

    summary = Summary(
        id=str(uuid.uuid4()),
        summary_type="monthly_recap",
        period_start=month_start,
        period_end=month_end,
        content=content,
        model_used=model_used,
        generation_time=gen_time,
        status="ready",
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(summary)
    await db.commit()
    await db.refresh(summary)
    return summary


async def generate_monthly_briefing(db: AsyncSession, month_start: str | None = None) -> Summary:
    """Forward-looking: what's ahead this month."""
    if not month_start:
        today = date.today()
        month_start = today.replace(day=1).isoformat()

    from calendar import monthrange
    d = date.fromisoformat(month_start)
    last_day = monthrange(d.year, d.month)[1]
    month_end = d.replace(day=last_day).isoformat()

    tasks_q = select(Task).where(
        Task.due_date >= month_start,
        Task.due_date <= month_end,
        Task.status.in_(["pending", "in_progress"]),
    ).order_by(Task.priority.desc())
    upcoming_tasks = (await db.execute(tasks_q)).scalars().all()

    overdue_q = select(Task).where(
        Task.due_date < month_start,
        Task.status.in_(["pending", "in_progress"]),
    )
    overdue_tasks = (await db.execute(overdue_q)).scalars().all()

    habits_q = select(Habit).where(Habit.active == 1)
    habits = (await db.execute(habits_q)).scalars().all()

    prev_month_start = (d.replace(day=1) - timedelta(days=1)).replace(day=1).isoformat()
    prev_month_end = (d - timedelta(days=1)).isoformat()

    avg_steps_q = select(func.avg(HealthMetric.value)).where(
        HealthMetric.metric_type == "steps",
        HealthMetric.date >= prev_month_start,
        HealthMetric.date <= prev_month_end,
    )
    avg_steps = (await db.execute(avg_steps_q)).scalar() or 0

    avg_sleep_q = select(func.avg(SleepSession.total_duration)).where(
        SleepSession.date >= prev_month_start,
        SleepSession.date <= prev_month_end,
    )
    avg_sleep = (await db.execute(avg_sleep_q)).scalar()

    avg_screen_q = select(func.avg(ScreenTimeEntry.duration_seconds)).where(
        ScreenTimeEntry.date >= prev_month_start,
        ScreenTimeEntry.date <= prev_month_end,
    )
    avg_screen_s = (await db.execute(avg_screen_q)).scalar() or 0

    mood_q = select(func.avg(JournalEntry.mood)).where(
        JournalEntry.date >= prev_month_start,
        JournalEntry.mood.isnot(None),
    )
    avg_mood = (await db.execute(mood_q)).scalar()

    task_groups: dict[str, list[str]] = {"urgent": [], "high": [], "medium": [], "low": []}
    for t in upcoming_tasks[:20]:
        task_groups.get(t.priority, task_groups["medium"]).append(t.title)

    prompt = f"""Month ahead: {month_start} to {month_end}

TASKS DUE THIS MONTH ({len(upcoming_tasks)} total):
{chr(10).join(f"- [{p.upper()}] " + ", ".join(titles[:3]) for p, titles in task_groups.items() if titles) or "No tasks due this month"}

CARRY-OVER OVERDUE ({len(overdue_tasks)}):
{chr(10).join(f"- {t.title}" for t in overdue_tasks[:5]) or "None"}

ACTIVE HABITS ({len(habits)}):
{", ".join(h.name for h in habits) or "No active habits"}

LAST MONTH'S HEALTH BASELINE:
Average daily steps: {avg_steps:,.0f}
Average nightly sleep: {f"{avg_sleep:.1f}h" if avg_sleep else "insufficient data"}
Average daily screen time: {round(avg_screen_s / 3600, 1)}h
{f"Average mood: {avg_mood:.1f}/10" if avg_mood else ""}

Please provide a monthly briefing with:
1. **This Month's Theme** — one overarching intention or focus for the month
2. **Top Priorities** — the 3-5 most important outcomes to achieve this month
3. **Task Roadmap** — how to sequence the workload across the month
4. **Habit Foundation** — which 2-3 habits to double down on this month and why
5. **Health Targets** — specific, realistic health goals based on last month's baseline
6. **Mindset for the Month** — one perspective shift or approach that will serve you well"""

    start = time.time()
    content, model_used = await generate_text(prompt, SYSTEM_MONTHLY_BRIEFING)
    gen_time = time.time() - start

    mbriefing = Summary(
        id=str(uuid.uuid4()),
        summary_type="monthly_briefing",
        period_start=month_start,
        period_end=month_end,
        content=content,
        model_used=model_used,
        generation_time=gen_time,
        status="ready",
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(mbriefing)
    await db.commit()
    await db.refresh(mbriefing)
    return mbriefing
