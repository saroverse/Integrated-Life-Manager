from sqlalchemy import ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Habit(Base):
    __tablename__ = "habits"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    frequency: Mapped[str] = mapped_column(String, default="daily")
    frequency_days: Mapped[str | None] = mapped_column(String)  # JSON: [0,1,2,3,4]
    frequency_interval: Mapped[int | None] = mapped_column(Integer, nullable=True)  # for 'interval': every N days
    frequency_count: Mapped[int | None] = mapped_column(Integer, nullable=True)  # for 'x_per_week': weekly quota
    target_count: Mapped[int] = mapped_column(Integer, default=1)
    icon: Mapped[str | None] = mapped_column(String)
    color: Mapped[str | None] = mapped_column(String)
    category: Mapped[str | None] = mapped_column(String)
    reminder_time: Mapped[str | None] = mapped_column(String)  # HH:MM
    active: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[str] = mapped_column(String, nullable=False)
    archived_at: Mapped[str | None] = mapped_column(String)


class HabitLog(Base):
    __tablename__ = "habit_logs"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    habit_id: Mapped[str] = mapped_column(String, ForeignKey("habits.id"), nullable=False)
    date: Mapped[str] = mapped_column(String, nullable=False)  # YYYY-MM-DD
    completed: Mapped[int] = mapped_column(Integer, nullable=False)  # 0/1
    count: Mapped[int] = mapped_column(Integer, default=1)
    note: Mapped[str | None] = mapped_column(Text)
    logged_at: Mapped[str] = mapped_column(String, nullable=False)

    __table_args__ = (Index("idx_habit_logs_habit_date", "habit_id", "date"),)
