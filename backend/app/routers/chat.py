import json
import uuid
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.chat import ChatMessage
from app.models.habit import Habit, HabitLog
from app.models.health import HealthMetric, SleepSession
from app.schemas.chat import ChatHistoryResponse, ChatMessageRequest, ChatMessageResponse
from app.services import summary_service
from app.services.ai_service import generate_chat_with_tools, generate_text
from app.services.chat_tools import TOOLS, execute_tool

router = APIRouter(prefix="/chat", tags=["chat"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _build_system_prompt(db: AsyncSession) -> str:
    today = date.today().isoformat()

    try:
        tasks = await summary_service._get_tasks_for_date(db, today)
    except Exception:
        tasks = []
    try:
        habits = await summary_service._get_habits_for_date(db, today)
    except Exception:
        habits = []
    try:
        health = await summary_service._get_health_for_date(db, today)
    except Exception:
        health = {}
    try:
        screen = await summary_service._get_screen_time_for_date(db, today)
    except Exception:
        screen = {"total_hours": 0, "top_apps": []}

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

SCREEN TIME TODAY:
Total: {screen.get('total_hours', 0)}h | Top apps: {', '.join(f"{a['name']} ({int(a.get('minutes', 0))}m)" for a in screen.get('top_apps', [])) or 'none'}

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

    # Call AI with tool-use loop
    try:
        content, model_used, actions_taken = await generate_chat_with_tools(
            messages,
            TOOLS,
            lambda name, args: execute_tool(name, args, db),
        )
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

    return {
        "id": assistant_msg.id,
        "session_id": assistant_msg.session_id,
        "role": assistant_msg.role,
        "content": assistant_msg.content,
        "model_used": assistant_msg.model_used,
        "timestamp": assistant_msg.timestamp,
        "actions_taken": actions_taken,
    }


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


# ── NLP command parsing ───────────────────────────────────────────────────────

class CommandRequest(BaseModel):
    text: str


_NLP_SYSTEM = """You are a command parser for a personal life manager app.
Parse the user's natural language input and return ONLY a JSON object — no explanation, no markdown.

Supported actions and their JSON shapes:
  {"action":"add_list_item","list_name":"shopping","item":"eggs"}
  {"action":"add_list_item","list_name":"watchlist","item":"Dune Part Two"}
  {"action":"add_list_item","list_name":"birthday","item":"AirPods"}
  {"action":"add_task","title":"Call dentist","due_date":"2025-05-01","due_time":"09:00","priority":"medium"}
  {"action":"add_event","title":"Meeting","date":"2025-05-01","start_time":"16:00","end_time":"17:00"}
  {"action":"log_habit","name":"meditation"}
  {"action":"log_habit","name":"reading"}
  {"action":"add_reminder","title":"Call mom","remind_at":"2025-05-01T18:00:00"}
  {"action":"unknown","original":"<original text>"}

Rules:
- Resolve relative dates (today, tomorrow, next Monday) to ISO format YYYY-MM-DD using today's date.
- For list items: map to the closest known list name. Common mappings: shopping list → "shopping", watch/movie list → "watchlist", birthday/Christmas/gift list → "birthday" or "christmas", packing list → "packing".
- If the list doesn't match any known type, use the literal words as list_name.
- Times must be HH:MM (24h).
- priority: low / medium / high — default medium.
- If you cannot parse the intent, return the "unknown" action.
- Return ONLY the JSON. No extra text."""


@router.post("/command")
async def parse_command(data: CommandRequest):
    """Parse a natural language command into a structured action."""
    today = date.today().isoformat()
    prompt = f"Today is {today}.\nUser said: {data.text}"
    try:
        raw, _ = await generate_text(prompt, _NLP_SYSTEM)
        # Strip markdown code fences if model wraps the JSON
        cleaned = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        parsed = json.loads(cleaned)
    except json.JSONDecodeError:
        parsed = {"action": "unknown", "original": data.text, "raw": raw}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Command parsing failed: {e}")
    return parsed
