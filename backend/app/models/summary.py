from sqlalchemy import Float, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Summary(Base):
    __tablename__ = "summaries"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    summary_type: Mapped[str] = mapped_column(String, nullable=False)
    period_start: Mapped[str] = mapped_column(String, nullable=False)
    period_end: Mapped[str] = mapped_column(String, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    model_used: Mapped[str | None] = mapped_column(String)
    context_data: Mapped[str | None] = mapped_column(Text)  # JSON snapshot
    generation_time: Mapped[float | None] = mapped_column(Float)  # seconds
    status: Mapped[str] = mapped_column(String, default="ready")
    created_at: Mapped[str] = mapped_column(String, nullable=False)

    __table_args__ = (Index("idx_summaries_type_period", "summary_type", "period_start"),)
