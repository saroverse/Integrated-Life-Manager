from pydantic import BaseModel, Field


class HabitCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: str | None = Field(None, max_length=500)
    frequency: str = "daily"
    frequency_days: str | None = Field(None, max_length=100)
    frequency_interval: int | None = Field(None, ge=2, le=30)
    frequency_count: int | None = Field(None, ge=1, le=6)
    target_count: int = 1
    icon: str | None = Field(None, max_length=50)
    color: str | None = Field(None, max_length=20)
    category: str | None = Field(None, max_length=100)
    reminder_time: str | None = Field(None, max_length=10)


class HabitUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    description: str | None = Field(None, max_length=500)
    frequency: str | None = None
    frequency_days: str | None = Field(None, max_length=100)
    frequency_interval: int | None = Field(None, ge=2, le=30)
    frequency_count: int | None = Field(None, ge=1, le=6)
    target_count: int | None = None
    icon: str | None = Field(None, max_length=50)
    color: str | None = Field(None, max_length=20)
    category: str | None = Field(None, max_length=100)
    reminder_time: str | None = Field(None, max_length=10)
    active: int | None = None


class HabitResponse(BaseModel):
    id: str
    name: str
    description: str | None
    frequency: str
    frequency_days: str | None
    frequency_interval: int | None
    frequency_count: int | None
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
    date: str = Field(..., min_length=10, max_length=10)
    completed: int = 1
    count: int = 1
    note: str | None = Field(None, max_length=500)


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
