# Integrated Life Manager

**A full-stack personal life management system with AI-generated daily briefings, wearable health data integration, and a cross-platform Android app — built entirely with Claude Code.**

![Python](https://img.shields.io/badge/Python-FastAPI-3776AB?logo=python) ![React](https://img.shields.io/badge/React-TypeScript-61DAFB?logo=react) ![Flutter](https://img.shields.io/badge/Flutter-Android-02569B?logo=flutter) ![Claude](https://img.shields.io/badge/Built_with-Claude_Code-orange) ![Ollama](https://img.shields.io/badge/AI-Ollama_+_Claude_API-blueviolet)

---

## What is this?

A personal productivity system that centralises tasks, habits, health data, screen time, and journaling — and uses local AI models to generate a morning briefing at 07:00 and an evening recap at 23:00.

The backend automatically pulls health data from my Amazfit smartwatch every 4 hours via the Zepp cloud API — no manual sync needed.

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
                                   Ollama (mistral:7b)
                                   + Claude API (fallback)
```

---

## Features

| Feature | Description |
|---|---|
| **Tasks** | Create, prioritise, and complete to-dos with due dates |
| **Habits** | Track daily/weekly habits with streaks and completion logs |
| **Health tracking** | Steps, heart rate, sleep stages — pulled from Amazfit via Zepp cloud |
| **Screen time** | Per-app Android usage, categorised and trended |
| **Journal** | Daily free-form entries with mood tracking |
| **AI briefings** | Morning briefing at 07:00 and evening recap at 23:00 |
| **AI chat** | Context-aware assistant with access to your tasks, habits, health, and screen time |
| **Reminders** | Push notifications to the Android app via Firebase |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Python 3.12 · FastAPI · SQLAlchemy (async) · SQLite · APScheduler · Uvicorn |
| AI | Ollama (`mistral:7b-instruct`) · Claude API (fallback) |
| Web Dashboard | React 18 · TypeScript · Tailwind CSS · Vite · TanStack Query |
| Android App | Flutter 3 · Dart · Firebase Cloud Messaging · Riverpod |
| Wearable | Amazfit Zepp Cloud API (steps, heart rate, sleep) |
| Auth | Static device token (request header) |

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
│   ├── app/
│   │   ├── main.py                FastAPI app + router registration
│   │   ├── models/                SQLAlchemy models (task, habit, health, journal…)
│   │   ├── routers/               API route handlers (/api/v1/…)
│   │   ├── services/
│   │   │   ├── ai_service.py      Ollama + Claude API cascade
│   │   │   ├── zepp_service.py    Zepp cloud health fetcher
│   │   │   └── notification_service.py  Firebase push
│   │   └── jobs/scheduler.py      APScheduler daily/weekly jobs
├── web_dashboard/                 React + Vite frontend
├── flutter_app/                   Android app
└── SETUP.md                       Step-by-step setup guide
```

---

## Setup

See [SETUP.md](SETUP.md) for full setup instructions.

```bash
# 1. Copy config template
cp backend/.env.example backend/.env
# Fill in your values (Zepp credentials, AI model, Firebase credentials path)

# 2. Start backend
cd backend && python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python run.py

# 3. Start web dashboard (dev mode)
cd web_dashboard && npm install && npm run dev
```

---

## API

All endpoints under `/api/v1/` require:
```
X-Device-Token: <your DEVICE_API_TOKEN from .env>
```

| Router | Prefix | Key Endpoints |
|---|---|---|
| Tasks | `/tasks` | CRUD, `/today`, `/{id}/complete` |
| Habits | `/habits` | CRUD, `/today`, `/{id}/log`, streak |
| Health | `/health` | `/sync`, `/summary`, `/sleep`, `/zepp-sync` |
| Screen time | `/screen-time` | `/sync`, `/daily`, `/trends` |
| Journal | `/journal` | CRUD, `/today` |
| Summaries | `/summaries` | list, `/latest`, `/generate` |
| Chat | `/chat` | `/message`, `/history` |

---

## About the Build

This project was built entirely using **Claude Code** — Anthropic's AI-native development tool. No manual Python or Dart was written; every component was designed and generated through AI-assisted development.

The goal was to explore the upper limits of what a non-traditional developer can build using modern AI tools: a production-quality, multi-layer system with real hardware integration and automated AI workflows.

> Total build time: a few weeks of evening sessions. Stack spans 3 languages (Python, TypeScript, Dart), 2 platforms (web + Android), and 2 AI model integrations.
