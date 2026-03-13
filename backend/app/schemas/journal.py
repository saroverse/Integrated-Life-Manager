from pydantic import BaseModel, Field


class JournalEntryCreate(BaseModel):
    date: str = Field(..., min_length=10, max_length=10)
    content: str = Field(..., min_length=1, max_length=50000)
    mood: int | None = Field(None, ge=1, le=10)
    energy: int | None = Field(None, ge=1, le=10)
    tags: str | None = Field(None, max_length=500)


class JournalEntryUpdate(BaseModel):
    content: str | None = Field(None, min_length=1, max_length=50000)
    mood: int | None = Field(None, ge=1, le=10)
    energy: int | None = Field(None, ge=1, le=10)
    tags: str | None = Field(None, max_length=500)


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
