from sqlalchemy import Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String, default="pending")
    priority: Mapped[str] = mapped_column(String, default="medium")
    due_date: Mapped[str | None] = mapped_column(String)
    due_time: Mapped[str | None] = mapped_column(String)  # HH:MM
    recurrence: Mapped[str | None] = mapped_column(String)
    recurrence_rule: Mapped[str | None] = mapped_column(String)
    tags: Mapped[str | None] = mapped_column(Text)
    project_id: Mapped[str | None] = mapped_column(String)
    completed_at: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[str] = mapped_column(String, nullable=False)
    updated_at: Mapped[str] = mapped_column(String, nullable=False)

    __table_args__ = (
        Index("idx_tasks_status", "status"),
        Index("idx_tasks_due_date", "due_date"),
    )
