from pydantic import BaseModel, Field


class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: str | None = Field(None, max_length=2000)
    status: str = "pending"
    priority: str = "medium"
    due_date: str | None = None
    due_time: str | None = None
    recurrence: str | None = Field(None, max_length=50)
    recurrence_rule: str | None = Field(None, max_length=500)
    tags: str | None = Field(None, max_length=500)
    project_id: str | None = Field(None, max_length=100)


class TaskUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = Field(None, max_length=2000)
    status: str | None = None
    priority: str | None = None
    due_date: str | None = None
    due_time: str | None = None
    recurrence: str | None = Field(None, max_length=50)
    recurrence_rule: str | None = Field(None, max_length=500)
    tags: str | None = Field(None, max_length=500)
    project_id: str | None = Field(None, max_length=100)


class TaskResponse(BaseModel):
    id: str
    title: str
    description: str | None
    status: str
    priority: str
    due_date: str | None
    due_time: str | None
    recurrence: str | None
    recurrence_rule: str | None
    tags: str | None
    project_id: str | None
    completed_at: str | None
    created_at: str
    updated_at: str

    model_config = {"from_attributes": True}
