from pydantic import BaseModel


class SummaryGenerateRequest(BaseModel):
    type: str
    date: str | None = None  # YYYY-MM-DD, defaults to today


class SummaryResponse(BaseModel):
    id: str
    summary_type: str
    period_start: str
    period_end: str
    content: str
    context_data: str | None
    model_used: str | None
    generation_time: float | None
    status: str
    created_at: str

    model_config = {"from_attributes": True}
