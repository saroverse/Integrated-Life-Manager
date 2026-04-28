"""
Tool definitions and executor for Claude tool-use in chat.

Claude sees these tools, picks which to call, and this module executes
the actual DB operations. Returns a human-readable result string that
goes back to Claude so it can craft a natural response.
"""
import uuid
from datetime import date, datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event
from app.models.habit import Habit, HabitLog
from app.models.list_item import ListItem, UserList
from app.models.reminder import Reminder
from app.models.task import Task


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _today() -> str:
    return date.today().isoformat()


# ── Tool schema definitions (sent to Claude API) ──────────────────────────────

TOOLS: list[dict] = [
    {
        "name": "add_task",
        "description": "Create a new task for the user.",
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Task title"},
                "description": {"type": "string", "description": "Optional details"},
                "priority": {"type": "string", "enum": ["low", "medium", "high"], "description": "Default: medium"},
                "due_date": {"type": "string", "description": "ISO date YYYY-MM-DD, optional"},
                "due_time": {"type": "string", "description": "HH:MM 24h, optional"},
            },
            "required": ["title"],
        },
    },
    {
        "name": "complete_task",
        "description": "Mark an existing task as done. Use list_tasks first to get the task ID.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "string", "description": "ID of the task to complete"},
            },
            "required": ["task_id"],
        },
    },
    {
        "name": "list_tasks",
        "description": "List tasks, optionally filtered by status or due date.",
        "input_schema": {
            "type": "object",
            "properties": {
                "status": {"type": "string", "enum": ["pending", "done", "all"], "description": "Default: pending"},
                "due_date": {"type": "string", "description": "Filter by due date YYYY-MM-DD, optional"},
            },
        },
    },
    {
        "name": "delete_task",
        "description": "Delete a task permanently. Use list_tasks first to get the task ID.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {"type": "string"},
            },
            "required": ["task_id"],
        },
    },
    {
        "name": "add_list_item",
        "description": "Add an item to an existing list (e.g. shopping list). Use list_lists to see available lists.",
        "input_schema": {
            "type": "object",
            "properties": {
                "list_name": {"type": "string", "description": "Name (or partial name) of the list to add to"},
                "item": {"type": "string", "description": "Text of the item to add"},
            },
            "required": ["list_name", "item"],
        },
    },
    {
        "name": "list_lists",
        "description": "Return all user lists with their IDs and names.",
        "input_schema": {"type": "object", "properties": {}},
    },
    {
        "name": "create_list",
        "description": "Create a new list.",
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "icon": {"type": "string", "description": "Emoji icon, optional"},
            },
            "required": ["name"],
        },
    },
    {
        "name": "check_list_item",
        "description": "Mark a list item as checked/done.",
        "input_schema": {
            "type": "object",
            "properties": {
                "list_name": {"type": "string"},
                "item_text": {"type": "string", "description": "Partial text of the item to find"},
            },
            "required": ["list_name", "item_text"],
        },
    },
    {
        "name": "log_habit",
        "description": "Mark a habit as completed for today.",
        "input_schema": {
            "type": "object",
            "properties": {
                "habit_name": {"type": "string", "description": "Name or partial name of the habit"},
            },
            "required": ["habit_name"],
        },
    },
    {
        "name": "list_habits",
        "description": "List all active habits and their completion status for today.",
        "input_schema": {"type": "object", "properties": {}},
    },
    {
        "name": "add_event",
        "description": "Add a calendar event.",
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "start_date": {"type": "string", "description": "YYYY-MM-DD"},
                "start_time": {"type": "string", "description": "HH:MM, optional"},
                "end_time": {"type": "string", "description": "HH:MM, optional"},
                "description": {"type": "string", "description": "Optional notes"},
            },
            "required": ["title", "start_date"],
        },
    },
    {
        "name": "add_reminder",
        "description": "Set a reminder that will notify the user at a specific time.",
        "input_schema": {
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "scheduled_at": {"type": "string", "description": "ISO datetime YYYY-MM-DDTHH:MM:SS"},
                "notes": {"type": "string", "description": "Optional extra info"},
            },
            "required": ["title", "scheduled_at"],
        },
    },
]


# ── Executor ──────────────────────────────────────────────────────────────────

async def execute_tool(name: str, args: dict, db: AsyncSession) -> str:
    """Run a tool call and return a plain-text result for Claude."""
    try:
        match name:
            case "add_task":
                return await _add_task(args, db)
            case "complete_task":
                return await _complete_task(args, db)
            case "list_tasks":
                return await _list_tasks(args, db)
            case "delete_task":
                return await _delete_task(args, db)
            case "add_list_item":
                return await _add_list_item(args, db)
            case "list_lists":
                return await _list_lists(db)
            case "create_list":
                return await _create_list(args, db)
            case "check_list_item":
                return await _check_list_item(args, db)
            case "log_habit":
                return await _log_habit(args, db)
            case "list_habits":
                return await _list_habits(db)
            case "add_event":
                return await _add_event(args, db)
            case "add_reminder":
                return await _add_reminder(args, db)
            case _:
                return f"Unknown tool: {name}"
    except Exception as e:
        return f"Tool error ({name}): {e}"


# ── Tool implementations ───────────────────────────────────────────────────────

async def _add_task(args: dict, db: AsyncSession) -> str:
    now = _now()
    task = Task(
        id=str(uuid.uuid4()),
        title=args["title"],
        description=args.get("description"),
        priority=args.get("priority", "medium"),
        due_date=args.get("due_date"),
        due_time=args.get("due_time"),
        status="pending",
        created_at=now,
        updated_at=now,
    )
    db.add(task)
    await db.commit()
    return f"Task created: \"{args['title']}\" (id={task.id})"


async def _complete_task(args: dict, db: AsyncSession) -> str:
    task = await db.get(Task, args["task_id"])
    if not task:
        return f"Task not found: {args['task_id']}"
    task.status = "done"
    task.completed_at = _now()
    task.updated_at = _now()
    await db.commit()
    return f"Task marked done: \"{task.title}\""


async def _list_tasks(args: dict, db: AsyncSession) -> str:
    status_filter = args.get("status", "pending")
    q = select(Task)
    if status_filter != "all":
        q = q.where(Task.status == status_filter)
    if args.get("due_date"):
        q = q.where(Task.due_date == args["due_date"])
    q = q.order_by(Task.due_date.asc().nullslast(), Task.created_at.asc()).limit(20)
    tasks = (await db.execute(q)).scalars().all()
    if not tasks:
        return "No tasks found."
    lines = [f"- [{t.id}] {t.title} (priority={t.priority}, due={t.due_date or 'none'})" for t in tasks]
    return "\n".join(lines)


async def _delete_task(args: dict, db: AsyncSession) -> str:
    task = await db.get(Task, args["task_id"])
    if not task:
        return f"Task not found: {args['task_id']}"
    title = task.title
    await db.delete(task)
    await db.commit()
    return f"Task deleted: \"{title}\""


async def _find_list(name: str, db: AsyncSession) -> UserList | None:
    q = select(UserList)
    rows = (await db.execute(q)).scalars().all()
    name_lower = name.lower()
    # exact match first, then partial
    for ul in rows:
        if ul.name.lower() == name_lower:
            return ul
    for ul in rows:
        if name_lower in ul.name.lower() or ul.name.lower() in name_lower:
            return ul
    return None


async def _add_list_item(args: dict, db: AsyncSession) -> str:
    ul = await _find_list(args["list_name"], db)
    if not ul:
        return f"List not found: \"{args['list_name']}\". Use list_lists to see available lists or create_list to make a new one."
    now = _now()
    item = ListItem(
        id=str(uuid.uuid4()),
        list_id=ul.id,
        text=args["item"],
        checked=0,
        sort_order=0,
        created_at=now,
    )
    db.add(item)
    ul.updated_at = now
    await db.commit()
    return f"Added \"{args['item']}\" to list \"{ul.name}\""


async def _list_lists(db: AsyncSession) -> str:
    q = select(UserList).order_by(UserList.created_at.asc())
    rows = (await db.execute(q)).scalars().all()
    if not rows:
        return "No lists found."
    return "\n".join(f"- [{ul.id}] {ul.icon or ''} {ul.name}" for ul in rows)


async def _create_list(args: dict, db: AsyncSession) -> str:
    now = _now()
    ul = UserList(
        id=str(uuid.uuid4()),
        name=args["name"],
        icon=args.get("icon", "📋"),
        created_at=now,
        updated_at=now,
    )
    db.add(ul)
    await db.commit()
    return f"List created: \"{args['name']}\" (id={ul.id})"


async def _check_list_item(args: dict, db: AsyncSession) -> str:
    ul = await _find_list(args["list_name"], db)
    if not ul:
        return f"List not found: \"{args['list_name']}\""
    q = select(ListItem).where(ListItem.list_id == ul.id, ListItem.checked == 0)
    items = (await db.execute(q)).scalars().all()
    text_lower = args["item_text"].lower()
    match = next((i for i in items if text_lower in i.text.lower() or i.text.lower() in text_lower), None)
    if not match:
        return f"Item not found in \"{ul.name}\": \"{args['item_text']}\""
    match.checked = 1
    match.checked_at = _now()
    await db.commit()
    return f"Checked off \"{match.text}\" in list \"{ul.name}\""


async def _log_habit(args: dict, db: AsyncSession) -> str:
    name_lower = args["habit_name"].lower()
    q = select(Habit).where(Habit.active == 1)
    habits = (await db.execute(q)).scalars().all()
    match = None
    for h in habits:
        if name_lower in h.name.lower() or h.name.lower() in name_lower:
            match = h
            break
    if not match:
        return f"No active habit found matching \"{args['habit_name']}\""
    today = _today()
    # Check if already logged today
    existing_q = select(HabitLog).where(HabitLog.habit_id == match.id, HabitLog.date == today)
    existing = (await db.execute(existing_q)).scalar_one_or_none()
    if existing:
        if existing.completed:
            return f"Habit \"{match.name}\" already logged as completed today."
        existing.completed = 1
        existing.logged_at = _now()
    else:
        log = HabitLog(
            id=str(uuid.uuid4()),
            habit_id=match.id,
            date=today,
            completed=1,
            count=1,
            logged_at=_now(),
        )
        db.add(log)
    await db.commit()
    return f"Habit logged: \"{match.name}\" for {today}"


async def _list_habits(db: AsyncSession) -> str:
    today = _today()
    q = select(Habit).where(Habit.active == 1).order_by(Habit.name.asc())
    habits = (await db.execute(q)).scalars().all()
    if not habits:
        return "No active habits."
    lines = []
    for h in habits:
        log_q = select(HabitLog).where(HabitLog.habit_id == h.id, HabitLog.date == today)
        log = (await db.execute(log_q)).scalar_one_or_none()
        status = "done" if (log and log.completed) else "pending"
        lines.append(f"- [{h.id}] {h.name} ({status})")
    return "\n".join(lines)


async def _add_event(args: dict, db: AsyncSession) -> str:
    now = _now()
    event = Event(
        id=str(uuid.uuid4()),
        title=args["title"],
        start_date=args["start_date"],
        start_time=args.get("start_time"),
        end_time=args.get("end_time"),
        description=args.get("description"),
        color="#4F6EF7",
        created_at=now,
        updated_at=now,
    )
    db.add(event)
    await db.commit()
    return f"Event created: \"{args['title']}\" on {args['start_date']}"


async def _add_reminder(args: dict, db: AsyncSession) -> str:
    now = _now()
    reminder = Reminder(
        id=str(uuid.uuid4()),
        title=args["title"],
        body=args.get("notes"),
        entity_type="custom",
        scheduled_at=args["scheduled_at"],
        status="pending",
        created_at=now,
    )
    db.add(reminder)
    await db.commit()
    return f"Reminder set: \"{args['title']}\" at {args['scheduled_at']}"
