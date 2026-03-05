from pydantic import BaseModel


class ChatMessageRequest(BaseModel):
    message: str
    session_id: str


class ChatMessageResponse(BaseModel):
    id: str
    session_id: str
    role: str
    content: str
    model_used: str | None
    timestamp: str

    model_config = {"from_attributes": True}


class ChatHistoryResponse(BaseModel):
    messages: list[ChatMessageResponse]
    total: int
