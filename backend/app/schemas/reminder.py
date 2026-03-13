from pydantic import BaseModel, Field


class ReminderCreate(BaseModel):
    entity_type: str = Field(..., min_length=1, max_length=50)
    entity_id: str | None = Field(None, max_length=100)
    title: str = Field(..., min_length=1, max_length=200)
    body: str | None = Field(None, max_length=1000)
    scheduled_at: str = Field(..., min_length=1, max_length=30)
    recurrence: str | None = Field(None, max_length=50)


class ReminderResponse(BaseModel):
    id: str
    entity_type: str
    entity_id: str | None
    title: str
    body: str | None
    scheduled_at: str
    recurrence: str | None
    status: str
    sent_at: str | None
    created_at: str

    model_config = {"from_attributes": True}


class DeviceTokenRegister(BaseModel):
    fcm_token: str = Field(..., min_length=1, max_length=500)
