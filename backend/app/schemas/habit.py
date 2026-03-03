from pydantic import BaseModel


class HabitCreate(BaseModel):
    name: str
    description: str | None = None
    frequency: str = "daily"
    frequency_days: str | None = None
    target_count: int = 1
    icon: str | None = None
    color: str | None = None
    category: str | None = None
    reminder_time: str | None = None


class HabitUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    frequency: str | None = None
    frequency_days: str | None = None
    target_count: int | None = None
    icon: str | None = None
    color: str | None = None
    category: str | None = None
    reminder_time: str | None = None
    active: int | None = None


class HabitResponse(BaseModel):
    id: str
    name: str
    description: str | None
    frequency: str
    frequency_days: str | None
    target_count: int
    icon: str | None
    color: str | None
    category: str | None
    reminder_time: str | None
    active: int
    created_at: str
    archived_at: str | None

    model_config = {"from_attributes": True}


class HabitLogCreate(BaseModel):
    date: str
    completed: int = 1
    count: int = 1
    note: str | None = None


class HabitLogResponse(BaseModel):
    id: str
    habit_id: str
    date: str
    completed: int
    count: int
    note: str | None
    logged_at: str

    model_config = {"from_attributes": True}


class StreakResponse(BaseModel):
    habit_id: str
    current_streak: int
    longest_streak: int
    total_completions: int
