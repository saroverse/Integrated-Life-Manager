from sqlalchemy import Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Event(Base):
    __tablename__ = "events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str | None] = mapped_column(String)
    start_date: Mapped[str] = mapped_column(String, nullable=False)  # YYYY-MM-DD
    start_time: Mapped[str | None] = mapped_column(String)           # HH:MM, null = all-day
    end_date: Mapped[str | None] = mapped_column(String)             # YYYY-MM-DD
    end_time: Mapped[str | None] = mapped_column(String)             # HH:MM
    location: Mapped[str | None] = mapped_column(String)
    color: Mapped[str | None] = mapped_column(String)                # hex e.g. #4F6EF7
    created_at: Mapped[str] = mapped_column(String, nullable=False)
    updated_at: Mapped[str] = mapped_column(String, nullable=False)

    __table_args__ = (Index("idx_events_start_date", "start_date"),)
