import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.database import init_db
from app.jobs.scheduler import scheduler, setup_scheduler
from app.routers import (
    dashboard,
    habits,
    health,
    journal,
    reminders,
    screen_time,
    summaries,
    tasks,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Integrated Life Manager backend...")
    await init_db()
    setup_scheduler()
    scheduler.start()
    logger.info("Backend ready.")
    yield
    scheduler.shutdown()
    logger.info("Backend shut down.")


app = FastAPI(title="Integrated Life Manager API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def auth_middleware(request: Request, call_next):
    # Skip auth for docs and health check
    if request.url.path in {"/", "/docs", "/openapi.json", "/health"}:
        return await call_next(request)
    # Skip auth for static files
    if request.url.path.startswith("/static") or request.url.path.startswith("/assets"):
        return await call_next(request)

    token = request.headers.get("X-Device-Token")
    if token != settings.device_api_token:
        return JSONResponse({"detail": "Unauthorized"}, status_code=401)
    return await call_next(request)


PREFIX = "/api/v1"

app.include_router(tasks.router, prefix=PREFIX)
app.include_router(habits.router, prefix=PREFIX)
app.include_router(health.router, prefix=PREFIX)
app.include_router(screen_time.router, prefix=PREFIX)
app.include_router(journal.router, prefix=PREFIX)
app.include_router(summaries.router, prefix=PREFIX)
app.include_router(dashboard.router, prefix=PREFIX)
app.include_router(reminders.router, prefix=PREFIX)


@app.get("/health")
async def health_check():
    return {"status": "ok", "version": "1.0.0"}


# Serve web dashboard static files if they exist
import os
static_dir = os.path.join(os.path.dirname(__file__), "..", "static")
if os.path.isdir(static_dir):
    app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")
