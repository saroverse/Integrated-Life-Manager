# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Backend (FastAPI)
```bash
# Start backend
cd backend && source venv/bin/activate && python3 run.py
# API docs: http://localhost:8000/docs

# Install dependencies
cd backend && source venv/bin/activate && pip install -r requirements.txt

# Run database migrations
cd backend && source venv/bin/activate && alembic upgrade head
```

### Web Dashboard (React + Vite)
```bash
# Development server (proxies API to :8000)
cd web_dashboard && npm run dev

# Build for production (outputs to backend/static/)
cd web_dashboard && npm run build
```

### Flutter App (Android)
```bash
cd flutter_app
flutter pub get
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Tests
```bash
# Flutter
cd flutter_app && flutter test

# Backend (no tests currently exist; use pytest if added)
cd backend && source venv/bin/activate && pytest
```

## Architecture

Three-layer system: FastAPI backend + React web dashboard + Flutter Android app, all sharing the same SQLite database through the backend API.

### Backend (`backend/`)
- **Entry:** `run.py` → `app/main.py` (Uvicorn + FastAPI)
- **Auth:** Single static `X-Device-Token` header (from `.env`), validated in middleware for all routes except `/docs`, `/health`, `/static`
- **Database:** Async SQLAlchemy + `aiosqlite` + SQLite (`ilm.db`). Tables auto-created on startup via `init_db()`. Use Alembic for schema migrations.
- **Routers:** 11 routers, all mounted under `/api/v1/` — tasks, habits, health, screen_time, journal, summaries, chat, events, planner, dashboard, reminders
- **AI cascade:** `ai_service.py` tries OpenClaw → Ollama (mistral:7b) → Claude API in order. Config via `.env` (`OPENCLAW_URL`, `OLLAMA_URL`, `CLAUDE_API_KEY`)
- **Scheduler:** APScheduler in `jobs/scheduler.py` — daily briefing (07:00), daily recap (23:00), weekly (Sun 22:00), monthly (1st), Zepp sync (every 4h), reminder checks

### Web Dashboard (`web_dashboard/`)
- React 18 + TypeScript + Tailwind + TanStack Query + Recharts
- `vite.config.ts` proxies `/api` to `http://localhost:8000` in dev; builds output to `../backend/static/` for production
- Pages in `src/pages/`, reusable components in `src/components/`, typed API client in `src/api/`, TypeScript interfaces in `src/types/`

### Flutter App (`flutter_app/`)
- State: Riverpod (`flutter_riverpod` + `riverpod_generator` for code gen)
- Navigation: GoRouter with a `ShellRoute` wrapping a `ScaffoldWithNav` bottom nav bar
- HTTP: Dio client in `services/api_service.dart`
- Offline: Hive local cache (`services/local_cache.dart`) with pending-operations queue; WorkManager for background sync
- Health data: `health` package → Health Connect → POST `/api/v1/health/sync`
- Screen time: `app_usage` package → POST `/api/v1/screen-time/sync`
- Backend URL and device token are hardcoded in `lib/config/constants.dart` — update before building

## Key Conventions

- **Python:** Always use the Python 3.12 venv at `backend/venv/`. System Python is 3.14 and incompatible with some wheels. Use `Float` not `Real` for SQLAlchemy float columns.
- **Async:** All backend DB operations use `async/await` with `AsyncSession`. Never use sync SQLAlchemy sessions.
- **Schemas:** Pydantic schemas in `backend/app/schemas/` define request/response shapes separate from SQLAlchemy models in `backend/app/models/`.
- **Static files:** The web dashboard must be built (`npm run build`) before FastAPI can serve it. FastAPI mounts `backend/static/` at root `/`, so the React app is served from the same origin as the API.
- **Zepp health sync:** Handled by `services/zepp_service.py` which calls the Zepp cloud API using credentials from `.env` (`ZEPP_EMAIL`, `ZEPP_PASSWORD`).
