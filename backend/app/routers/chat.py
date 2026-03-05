import uuid
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.chat import ChatMessage
from app.models.habit import Habit, HabitLog
from app.models.health import HealthMetric, SleepSession
from app.schemas.chat import ChatHistoryResponse, ChatMessageRequest, ChatMessageResponse
from app.services import summary_service
from app.services.ai_service import generate_chat

router = APIRouter(prefix="/chat", tags=["chat"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _build_system_prompt(db: AsyncSession) -> str:
    today = date.today().isoformat()

    tasks = await summary_service._get_tasks_for_date(db, today)
    habits = await summary_service._get_habits_for_date(db, today)
    health = await summary_service._get_health_for_date(db, today)

    # 7-day averages
    seven_days_ago = (date.today() - timedelta(days=7)).isoformat()

    steps_q = select(func.avg(func.nullif(
        select(func.sum(HealthMetric.value))
        .where(HealthMetric.metric_type == "steps", HealthMetric.date >= seven_days_ago)
        .scalar_subquery(), 0
    )))
    avg_steps_q = (
        select(func.avg(HealthMetric.value))
        .where(HealthMetric.metric_type == "steps", HealthMetric.date >= seven_days_ago)
    )
    avg_steps = (await db.execute(avg_steps_q)).scalar() or 0

    avg_sleep_q = (
        select(func.avg(SleepSession.total_duration))
        .where(SleepSession.date >= seven_days_ago)
    )
    avg_sleep = (await db.execute(avg_sleep_q)).scalar()

    # Habit completion rate over 7 days
    total_logs_q = select(func.count(HabitLog.id)).where(HabitLog.date >= seven_days_ago)
    done_logs_q = select(func.count(HabitLog.id)).where(
        HabitLog.date >= seven_days_ago, HabitLog.completed == 1
    )
    total_logs = (await db.execute(total_logs_q)).scalar() or 0
    done_logs = (await db.execute(done_logs_q)).scalar() or 0
    habit_pct = round(done_logs / total_logs * 100) if total_logs else 0

    seven_day_summary = (
        f"Steps: {int(avg_steps):,}/day avg"
        + (f" | Sleep: {avg_sleep:.1f}h avg" if avg_sleep else "")
        + f" | Habits: {habit_pct}% completion"
    )

    return f"""You are a personal life assistant for the user. Be direct and concise.
Use bullet points or short paragraphs. Avoid unnecessary filler.

TODAY ({today}):
TASKS:
{summary_service._format_tasks(tasks)}

HABITS:
{summary_service._format_habits(habits)}

HEALTH:
{summary_service._format_health(health)}

LAST 7 DAYS (averages):
{seven_day_summary}"""


@router.post("/message", response_model=ChatMessageResponse)
async def send_message(data: ChatMessageRequest, db: AsyncSession = Depends(get_db)):
    # Load recent conversation history (last 40 messages)
    history_q = (
        select(ChatMessage)
        .where(ChatMessage.session_id == data.session_id)
        .order_by(ChatMessage.timestamp.asc())
        .limit(40)
    )
    history = (await db.execute(history_q)).scalars().all()

    # Build messages list
    system_prompt = await _build_system_prompt(db)
    messages = [{"role": "system", "content": system_prompt}]
    for msg in history:
        messages.append({"role": msg.role, "content": msg.content})
    messages.append({"role": "user", "content": data.message})

    # Persist user message
    user_msg = ChatMessage(
        id=str(uuid.uuid4()),
        session_id=data.session_id,
        role="user",
        content=data.message,
        model_used=None,
        timestamp=_now(),
    )
    db.add(user_msg)

    # Call AI
    try:
        content, model_used = await generate_chat(messages)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI generation failed: {e}")

    # Persist assistant response
    assistant_msg = ChatMessage(
        id=str(uuid.uuid4()),
        session_id=data.session_id,
        role="assistant",
        content=content,
        model_used=model_used,
        timestamp=_now(),
    )
    db.add(assistant_msg)
    await db.commit()
    await db.refresh(assistant_msg)

    return assistant_msg


@router.get("/history", response_model=ChatHistoryResponse)
async def get_history(
    session_id: str,
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
):
    q = (
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.timestamp.asc())
        .limit(limit)
        .offset(offset)
    )
    messages = (await db.execute(q)).scalars().all()
    return ChatHistoryResponse(messages=list(messages), total=len(messages))


@router.delete("/history", status_code=204)
async def clear_history(session_id: str, db: AsyncSession = Depends(get_db)):
    await db.execute(delete(ChatMessage).where(ChatMessage.session_id == session_id))
    await db.commit()
