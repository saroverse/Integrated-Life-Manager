from pydantic import BaseModel


class JournalEntryCreate(BaseModel):
    date: str
    content: str
    mood: int | None = None
    energy: int | None = None
    tags: str | None = None


class JournalEntryUpdate(BaseModel):
    content: str | None = None
    mood: int | None = None
    energy: int | None = None
    tags: str | None = None


class JournalEntryResponse(BaseModel):
    id: str
    date: str
    content: str
    mood: int | None
    energy: int | None
    tags: str | None
    created_at: str
    updated_at: str

    model_config = {"from_attributes": True}
