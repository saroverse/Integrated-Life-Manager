# Integrated Life Manager

A personal life management system that centralises tasks, habits, health data, screen time, and journaling — with AI-generated daily briefings, recaps, and a context-aware chat assistant.

---

## Features

| Feature | Description |
| --- | --- |
| **Tasks** | Create, prioritise, and complete to-dos with due dates |
| **Habits** | Track daily/weekly habits with streaks and completion logs |
| **Health tracking** | Steps, heart rate, sleep stages — pulled from Amazfit via Zepp cloud |
| **Screen time** | Per-app Android usage, categorised and trended |
| **Journal** | Daily free-form entries with mood tracking |
| **AI briefings** | Morning briefing at 07:00 and evening recap at 23:00 |
| **AI chat** | Context-aware assistant with access to your tasks, habits, health, and screen time |
| **Reminders** | Push notifications to the Android app via Firebase |

---

## Architecture

```text
Amazfit Heliostrap
       │
       ▼
  Zepp cloud ──── Zepp service (backend, every 4 h) ──┐
                                                        │
  Android app                                           ▼
  (screen time) ─── POST /api/v1/screen-time ──────► SQLite DB
                                                        │
                                              FastAPI backend (Mac Mini :8000)
                                                        │
                                     ┌──────────────────┼──────────────────┐
                                     ▼                  ▼                  ▼
                               Web dashboard       Flutter app         /docs API
                               (React + Vite)       (Android)
                                                        │
                                                   APScheduler
                                                   07:00 briefing
                                                   23:00 recap
                                                        │
                                                   Ollama (mistral:7b)
                                                   Claude API (fallback)
```

---

## Interfaces

| Interface | URL / method |
| --- | --- |
| Web dashboard | `http://localhost:8000` |
| API docs (Swagger) | `http://localhost:8000/docs` |
| Android app | Flutter APK installed via ADB |
| AI chat | Built into the Android app |

---

## Project structure

```text
Integrated Life Manager/
├── backend/
│   ├── run.py                        entry point (uvicorn)
│   ├── .env                          configuration (credentials, tokens, AI model)
│   ├── requirements.txt
│   ├── ilm.db                        SQLite database
│   ├── static/                       built web dashboard (served at /)
│   └── app/
│       ├── main.py                   FastAPI app + router registration
│       ├── config.py                 settings (pydantic-settings, reads .env)
│       ├── database.py               async SQLAlchemy session
│       ├── models/
│       │   ├── task.py
│       │   ├── habit.py              Habit + HabitLog
│       │   ├── health.py             HealthMetric, SleepSession, Workout
│       │   ├── screen_time.py
│       │   ├── journal.py
│       │   ├── summary.py            AI-generated summaries
│       │   ├── chat.py               chat message history
│       │   └── reminder.py           reminders + FCM token store
│       ├── routers/                  API route handlers (/api/v1/...)
│       │   ├── tasks.py
│       │   ├── habits.py
│       │   ├── health.py
│       │   ├── screen_time.py
│       │   ├── journal.py
│       │   ├── summaries.py
│       │   ├── chat.py
│       │   ├── reminders.py
│       │   └── dashboard.py
│       ├── services/
│       │   ├── ai_service.py         Ollama + Claude API wrapper
│       │   ├── summary_service.py    context assembly for AI summaries
│       │   ├── zepp_service.py       Zepp cloud health data fetcher
│       │   └── notification_service.py  Firebase push
│       └── jobs/
│           └── scheduler.py          APScheduler jobs
├── web_dashboard/
│   ├── src/
│   │   ├── pages/                    Dashboard, Tasks, Habits, Health,
│   │   │                             ScreenTime, Journal, Summaries
│   │   ├── components/layout/
│   │   └── api/                      typed Axios client
│   └── package.json
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/constants.dart     backend URL + device token
│   │   ├── screens/                  Home, Tasks, Habits, Health,
│   │   │                             Briefings, Chat, Settings
│   │   └── services/                 api_service, sync_service,
│   │                                 health_service, screen_time_service
│   └── pubspec.yaml
├── SETUP.md                          step-by-step setup guide
└── README.md                         this file
```

---

## API

All endpoints are under `/api/v1/` and require:

```text
X-Device-Token: <DEVICE_API_TOKEN from .env>
```

| Router | Prefix | Endpoints |
| --- | --- | --- |
| Dashboard | `/dashboard` | `/today`, `/stats` |
| Tasks | `/tasks` | CRUD, `/today`, `/{id}/complete` |
| Habits | `/habits` | CRUD, `/today`, `/{id}/log`, `/{id}/streak` |
| Health | `/health` | `/sync`, `/summary`, `/metrics`, `/sleep`, `/workouts`, `/zepp-sync` |
| Screen time | `/screen-time` | `/sync`, `/daily`, `/trends` |
| Journal | `/journal` | CRUD, `/today` |
| Summaries | `/summaries` | list, `/latest`, `/{id}`, `/generate` |
| Chat | `/chat` | `/message`, `/history` |
| Reminders | `/reminders` | CRUD, `/dismiss`, `/snooze` |

Full interactive docs: **`http://localhost:8000/docs`**

---

## Health data

Health is pulled from Zepp's cloud on the backend every 4 hours — no phone interaction required after initial credential setup.

**Collected:** steps · resting heart rate · sleep (total / deep / REM / light / score)

> The Flutter app also contains a Health Connect integration (phone-side sync), but it requires Play Store publication for Google's permission flow to work. Zepp cloud is the active method.

---

## Tech stack

| Layer | Technology |
| --- | --- |
| Backend | Python 3.12, FastAPI, SQLAlchemy (async), SQLite, APScheduler, uvicorn |
| AI | Ollama (`mistral:7b-instruct`), Claude API (fallback) |
| Web | React 18, TypeScript, Tailwind CSS, Vite |
| Mobile | Flutter 3, Dart, Firebase Cloud Messaging |
| Auth | Static device token (request header) |

---

## Setup

See [SETUP.md](SETUP.md) for full installation instructions.
