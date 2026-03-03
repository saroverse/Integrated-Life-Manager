from pydantic import BaseModel


class ReminderCreate(BaseModel):
    entity_type: str
    entity_id: str | None = None
    title: str
    body: str | None = None
    scheduled_at: str
    recurrence: str | None = None


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
    fcm_token: str
