from pydantic import BaseModel, Field


class EventCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: str | None = Field(None, max_length=2000)
    start_date: str = Field(..., min_length=10, max_length=10)
    start_time: str | None = Field(None, max_length=10)
    end_date: str | None = Field(None, max_length=10)
    end_time: str | None = Field(None, max_length=10)
    location: str | None = Field(None, max_length=500)
    color: str | None = Field(None, max_length=20)


class EventUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = Field(None, max_length=2000)
    start_date: str | None = Field(None, max_length=10)
    start_time: str | None = Field(None, max_length=10)
    end_date: str | None = Field(None, max_length=10)
    end_time: str | None = Field(None, max_length=10)
    location: str | None = Field(None, max_length=500)
    color: str | None = Field(None, max_length=20)


class EventResponse(BaseModel):
    id: str
    title: str
    description: str | None
    start_date: str
    start_time: str | None
    end_date: str | None
    end_time: str | None
    location: str | None
    color: str | None
    created_at: str
    updated_at: str

    model_config = {"from_attributes": True}
