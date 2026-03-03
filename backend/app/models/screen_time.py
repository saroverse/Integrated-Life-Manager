from sqlalchemy import Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ScreenTimeEntry(Base):
    __tablename__ = "screen_time_entries"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    date: Mapped[str] = mapped_column(String, nullable=False)  # YYYY-MM-DD
    app_package: Mapped[str] = mapped_column(String, nullable=False)
    app_name: Mapped[str] = mapped_column(String, nullable=False)
    app_category: Mapped[str | None] = mapped_column(String)
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    launch_count: Mapped[int] = mapped_column(Integer, default=0)
    first_used: Mapped[str | None] = mapped_column(String)
    last_used: Mapped[str | None] = mapped_column(String)
    synced_at: Mapped[str] = mapped_column(String, nullable=False)

    __table_args__ = (
        Index("idx_screen_time_date", "date"),
        UniqueConstraint("app_package", "date", name="uq_screen_time_app_date"),
    )
