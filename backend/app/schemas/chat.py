from pydantic import BaseModel, Field


class ChatMessageRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=10000)
    session_id: str = Field(..., min_length=1, max_length=100)


class ChatMessageResponse(BaseModel):
    id: str
    session_id: str
    role: str
    content: str
    model_used: str | None
    timestamp: str
    actions_taken: list[str] = []

    model_config = {"from_attributes": True}


class ChatHistoryResponse(BaseModel):
    messages: list[ChatMessageResponse]
    total: int
