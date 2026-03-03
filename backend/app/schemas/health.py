from pydantic import BaseModel


class HealthMetricCreate(BaseModel):
    id: str
    metric_type: str
    value: float
    unit: str
    recorded_at: str
    date: str
    source: str = "health_connect"
    raw_data: str | None = None


class HealthMetricResponse(BaseModel):
    id: str
    metric_type: str
    value: float
    unit: str
    recorded_at: str
    date: str
    source: str
    synced_at: str

    model_config = {"from_attributes": True}


class SleepSessionCreate(BaseModel):
    id: str
    date: str
    bedtime: str
    wake_time: str
    total_duration: float | None = None
    deep_sleep: float | None = None
    rem_sleep: float | None = None
    light_sleep: float | None = None
    awake_time: float | None = None
    sleep_score: int | None = None
    source: str = "health_connect"
    raw_data: str | None = None


class SleepSessionResponse(BaseModel):
    id: str
    date: str
    bedtime: str
    wake_time: str
    total_duration: float | None
    deep_sleep: float | None
    rem_sleep: float | None
    light_sleep: float | None
    awake_time: float | None
    sleep_score: int | None
    source: str
    synced_at: str

    model_config = {"from_attributes": True}


class WorkoutCreate(BaseModel):
    id: str
    workout_type: str
    start_time: str
    end_time: str
    duration: float | None = None
    calories: float | None = None
    distance: float | None = None
    avg_heart_rate: int | None = None
    max_heart_rate: int | None = None
    steps: int | None = None
    date: str
    source: str | None = None
    raw_data: str | None = None


class HealthSyncPayload(BaseModel):
    metrics: list[HealthMetricCreate] = []
    sleep_sessions: list[SleepSessionCreate] = []
    workouts: list[WorkoutCreate] = []
