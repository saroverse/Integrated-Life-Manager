from pydantic import BaseModel


class EventCreate(BaseModel):
    title: str
    description: str | None = None
    start_date: str
    start_time: str | None = None
    end_date: str | None = None
    end_time: str | None = None
    location: str | None = None
    color: str | None = None


class EventUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    start_date: str | None = None
    start_time: str | None = None
    end_date: str | None = None
    end_time: str | None = None
    location: str | None = None
    color: str | None = None


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
