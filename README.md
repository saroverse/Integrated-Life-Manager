# Integrated Life Manager

**A full-stack personal life management system with AI-generated daily briefings, wearable health data integration, and a cross-platform Android app — built entirely with Claude Code.**

![Python](https://img.shields.io/badge/Python-FastAPI-3776AB?logo=python) ![React](https://img.shields.io/badge/React-TypeScript-61DAFB?logo=react) ![Flutter](https://img.shields.io/badge/Flutter-Android-02569B?logo=flutter) ![Claude](https://img.shields.io/badge/Built_with-Claude_Code-orange) ![AI](https://img.shields.io/badge/AI-Claude_API_+_Groq-blueviolet)

---

## What is this?

A personal productivity system that centralises tasks, habits, health data, screen time, and journaling — and uses AI to generate a morning briefing at 07:00 and an evening recap at 23:00.

The backend automatically pulls health data from an Amazfit smartwatch every 4 hours via the Zepp cloud API — no manual sync needed. Screen time is tracked directly on the Android device using native Android UsageEvents (matching what Samsung Digital Wellbeing reports, not the inflated `queryUsageStats()` numbers).

---

## Architecture

```text
Amazfit Smartwatch
       │
       ▼
  Zepp Cloud ──── Backend sync (every 4h) ──┐
                                             │
  Android app                               ▼
  (screen time) ── POST /api/v1/ ───────► SQLite DB
                                             │
                                   FastAPI Backend (:8000)
                                             │
                          ┌──────────────────┼──────────────┐
                          ▼                  ▼              ▼
                    Web Dashboard       Flutter App     Swagger /docs
                    (React + Vite)      (Android)
                                             │
                                        APScheduler
                                        07:00 briefing
                                        23:00 recap
                                             │
                                   Groq (llama-3.1-8b, scheduled jobs)
                                   + Claude API (user-facing chat)
```

---

## Features

| Feature | Description |
|---|---|
| **Tasks** | Create, prioritise, and complete to-dos with swipe gestures |
| **Habits** | Daily/weekly/interval habits with streaks, calendar view, and completion logs |
| **Health tracking** | Steps, heart rate, HRV, and sleep stages — pulled from Amazfit via Zepp cloud |
| **Screen time** | Per-app Android usage via native UsageEvents API, categorised and trended |
| **Journal** | Daily free-form entries with mood tracking |
| **AI briefings** | Morning briefing at 07:00 and evening recap at 23:00 (Groq / Claude API) |
| **AI chat** | Context-aware assistant with tool-use: can create tasks/habits, query health data |
| **Reminders** | Push notifications to the Android app via Firebase |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Python 3.12 · FastAPI · SQLAlchemy (async) · SQLite · APScheduler · Uvicorn |
| AI — chat | Claude API (`claude-haiku-4-5`) with tool-use for structured actions |
| AI — jobs | Groq API (`llama-3.1-8b-instant`) via OpenClaw local proxy |
| Web Dashboard | React 18 · TypeScript · Tailwind CSS · Vite · TanStack Query · Recharts |
| Android App | Flutter 3 · Dart · Riverpod · GoRouter · Dio · Firebase Cloud Messaging |
| Wearable | Amazfit → Zepp Cloud API (steps, heart rate, HRV, sleep stages) |
| Screen time | Native Kotlin `UsageEvents` MethodChannel (MOVE_TO_FOREGROUND/BACKGROUND) |
| Auth | Static device token (X-Device-Token header) |

---

## Interfaces

| Interface | Access |
|---|---|
| Web dashboard | `http://localhost:8000` |
| API docs (Swagger) | `http://localhost:8000/docs` |
| Android app | Flutter APK via ADB |
| AI chat | Built into the Android app |

---

## Project Structure

```text
IntegratedLifeManager/
├── backend/
│   ├── run.py                     entry point (uvicorn)
│   ├── .env.example               config template (copy to .env)
│   ├── requirements.txt
│   └── app/
│       ├── main.py                FastAPI app + router registration
│       ├── models/                SQLAlchemy models (task, habit, health, journal…)
│       ├── routers/               API route handlers (/api/v1/…)
│       ├── services/
│       │   ├── ai_service.py      Claude API + Groq cascade
│       │   ├── zepp_service.py    Zepp cloud health fetcher
│       │   └── notification_service.py  Firebase push
│       └── jobs/scheduler.py      APScheduler daily/weekly jobs
├── web_dashboard/                 React + Vite frontend
├── flutter_app/                   Android app (Flutter + Kotlin native channel)
└── SETUP.md                       Step-by-step setup guide
```

---

## Setup

See [SETUP.md](SETUP.md) for full setup instructions.

```bash
# 1. Copy config template
cp backend/.env.example backend/.env
# Fill in your values: DEVICE_API_TOKEN, CLAUDE_API_KEY, GROQ_API_KEY, Zepp credentials

# 2. Start backend
cd backend && python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python run.py
# → http://localhost:8000/docs

# 3. Start web dashboard (dev mode)
cd web_dashboard && npm install && npm run dev

# 4. Build Android app
cd flutter_app
cp dart_defines.example.json dart_defines.json   # fill in backend URL + token
flutter pub get
flutter build apk --release --dart-define-from-file=dart_defines.json
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## API

All endpoints under `/api/v1/` require:
```
X-Device-Token: <your DEVICE_API_TOKEN from .env>
```

| Router | Key Endpoints |
|---|---|
| Tasks | CRUD · `/today` · `/{id}/complete` |
| Habits | CRUD · `/today` · `/{id}/log` · streak |
| Health | `/summary` · `/sleep` · `/zepp-sync` |
| Screen time | `/sync` · `/daily` · `/trends` |
| Journal | CRUD · `/today` |
| Summaries | `/latest` · `/generate` |
| Chat | `/message` · `/history` (tool-use enabled) |

---

## Notable Implementation Details

- **AI tool-use**: The chat endpoint uses Claude's tool-use API — the model can call backend functions (create task, log habit, query health summary) directly from conversation, not just generate text.
- **Screen time accuracy**: Android's `queryUsageStats()` over-counts by including background audio and PiP. The app uses a native Kotlin `MethodChannel` with `queryEvents(MOVE_TO_FOREGROUND / MOVE_TO_BACKGROUND)` instead, matching Digital Wellbeing numbers.
- **Zepp sync fallback**: If today's steps haven't synced yet (Zepp runs at 6:30am), the health screen automatically falls back to yesterday's data with a label.
- **Offline support**: The Flutter app queues failed mutations in Hive and replays them on reconnect via WorkManager.

---

## About the Build

This project was built entirely using **Claude Code** — Anthropic's AI-native CLI tool. The goal was to explore the upper limits of what's possible using modern AI-assisted development: a production-quality, multi-layer system with real hardware integration, native platform channels, and automated AI workflows.

> Stack spans 3 languages (Python, TypeScript, Dart/Kotlin), 2 platforms (web + Android), and multiple AI integrations. Built over several weeks of evening sessions.
