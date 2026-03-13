from pydantic import BaseModel, Field


class ScreenTimeEntryCreate(BaseModel):
    id: str = Field(..., min_length=1, max_length=200)
    date: str = Field(..., min_length=10, max_length=10)
    app_package: str = Field(..., min_length=1, max_length=200)
    app_name: str = Field(..., min_length=1, max_length=200)
    app_category: str | None = Field(None, max_length=100)
    duration_seconds: int = Field(..., ge=0)
    launch_count: int = Field(0, ge=0)
    first_used: str | None = Field(None, max_length=30)
    last_used: str | None = Field(None, max_length=30)


class ScreenTimeSyncPayload(BaseModel):
    entries: list[ScreenTimeEntryCreate] = Field(..., max_length=500)


class ScreenTimeEntryResponse(BaseModel):
    id: str
    date: str
    app_package: str
    app_name: str
    app_category: str | None
    duration_seconds: int
    launch_count: int
    first_used: str | None
    last_used: str | None
    synced_at: str

    model_config = {"from_attributes": True}
