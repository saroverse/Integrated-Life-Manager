from sqlalchemy import Float, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class HealthMetric(Base):
    __tablename__ = "health_metrics"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    metric_type: Mapped[str] = mapped_column(String, nullable=False)
    value: Mapped[float] = mapped_column(Float, nullable=False)
    unit: Mapped[str] = mapped_column(String, nullable=False)
    recorded_at: Mapped[str] = mapped_column(String, nullable=False)
    date: Mapped[str] = mapped_column(String, nullable=False)  # YYYY-MM-DD
    source: Mapped[str] = mapped_column(String, default="health_connect")
    raw_data: Mapped[str | None] = mapped_column(Text)
    synced_at: Mapped[str] = mapped_column(String, nullable=False)

    __table_args__ = (Index("idx_health_metrics_type_date", "metric_type", "date"),)


class SleepSession(Base):
    __tablename__ = "sleep_sessions"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    date: Mapped[str] = mapped_column(String, nullable=False)  # YYYY-MM-DD
    bedtime: Mapped[str] = mapped_column(String, nullable=False)
    wake_time: Mapped[str] = mapped_column(String, nullable=False)
    total_duration: Mapped[float | None] = mapped_column(Float)  # hours
    deep_sleep: Mapped[float | None] = mapped_column(Float)
    rem_sleep: Mapped[float | None] = mapped_column(Float)
    light_sleep: Mapped[float | None] = mapped_column(Float)
    awake_time: Mapped[float | None] = mapped_column(Float)
    sleep_score: Mapped[int | None] = mapped_column()
    source: Mapped[str] = mapped_column(String, default="health_connect")
    raw_data: Mapped[str | None] = mapped_column(Text)
    synced_at: Mapped[str] = mapped_column(String, nullable=False)

    __table_args__ = (Index("idx_sleep_sessions_date", "date"),)


class Workout(Base):
    __tablename__ = "workouts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    workout_type: Mapped[str] = mapped_column(String, nullable=False)
    start_time: Mapped[str] = mapped_column(String, nullable=False)
    end_time: Mapped[str] = mapped_column(String, nullable=False)
    duration: Mapped[float | None] = mapped_column(Float)  # minutes
    calories: Mapped[float | None] = mapped_column(Float)
    distance: Mapped[float | None] = mapped_column(Float)  # km
    avg_heart_rate: Mapped[int | None] = mapped_column()
    max_heart_rate: Mapped[int | None] = mapped_column()
    steps: Mapped[int | None] = mapped_column()
    date: Mapped[str] = mapped_column(String, nullable=False)
    source: Mapped[str | None] = mapped_column(String)
    raw_data: Mapped[str | None] = mapped_column(Text)
    synced_at: Mapped[str] = mapped_column(String, nullable=False)

    __table_args__ = (Index("idx_workouts_date", "date"),)
