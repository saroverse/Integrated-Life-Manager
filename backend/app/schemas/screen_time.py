from pydantic import BaseModel


class ScreenTimeEntryCreate(BaseModel):
    id: str
    date: str
    app_package: str
    app_name: str
    app_category: str | None = None
    duration_seconds: int
    launch_count: int = 0
    first_used: str | None = None
    last_used: str | None = None


class ScreenTimeSyncPayload(BaseModel):
    entries: list[ScreenTimeEntryCreate]


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
