from sqlalchemy import Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class UserList(Base):
    __tablename__ = "user_lists"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    icon: Mapped[str | None] = mapped_column(String)   # emoji or material icon name
    color: Mapped[str | None] = mapped_column(String)  # hex color
    created_at: Mapped[str] = mapped_column(String, nullable=False)
    updated_at: Mapped[str] = mapped_column(String, nullable=False)


class ListItem(Base):
    __tablename__ = "list_items"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    list_id: Mapped[str] = mapped_column(String, nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    checked: Mapped[int] = mapped_column(Integer, default=0)   # 0/1
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[str] = mapped_column(String, nullable=False)
    checked_at: Mapped[str | None] = mapped_column(String)

    __table_args__ = (Index("idx_list_items_list_id", "list_id"),)
