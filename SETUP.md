# Integrated Life Manager — Setup Guide

## What You've Got

```
integrated-life-manager/
├── backend/          ← Python FastAPI server (runs on your Mac)
├── web_dashboard/    ← React web dashboard (built, served by backend)
└── flutter_app/      ← Android app (manages habits/tasks, syncs health data)
```

**Data flow:**
```
Amazfit Heliostrap → Zepp app → Health Connect → Flutter app → Backend → Web dashboard + AI summaries
```

---

## Step 1: Start the Backend

> The backend is the central hub. Start this first, keep it running.

```bash
cd backend

# First time only: create your .env
cp .env.example .env
# Edit .env — change DEVICE_API_TOKEN to a random secret string

# Activate the Python 3.12 virtual environment
source venv/bin/activate

# Start the server
python3 run.py
```

The server starts at **http://localhost:8000**
API docs: **http://localhost:8000/docs**

**Keep the terminal open.** The backend schedules AI summaries automatically.

---

## Step 2: Open the Web Dashboard

With the backend running, open: **http://localhost:8000**

The dashboard is already built and served. You can:
- Create tasks and habits
- View health data after syncing from the phone
- Read AI summaries (generated automatically or on demand)

---

## Step 3: Install Ollama (Local AI)

```bash
brew install ollama

# Pull the AI model (~4 GB download)
ollama pull mistral:7b-instruct

# Start Ollama (runs as a background service)
ollama serve
```

Once running, the backend will use it for AI summaries. Test it:
```bash
curl -H "X-Device-Token: your-token" \
  -H "Content-Type: application/json" \
  -X POST http://localhost:8000/api/v1/summaries/generate \
  -d '{"type": "daily_briefing"}'
```

---

## Step 4: Set Up the Android App

### 4a. Install Flutter

```bash
# Install Flutter via homebrew
brew install --cask flutter

# Or download from https://flutter.dev/docs/get-started/install/macos
flutter doctor  # check setup
```

### 4b. Configure Backend URL

Edit [flutter_app/lib/config/constants.dart](flutter_app/lib/config/constants.dart):

```dart
static const String backendUrl = 'http://192.168.1.100:8000';  // ← your Mac's WiFi IP
static const String deviceToken = 'your-token-here';           // ← same as .env
```

**Find your Mac's IP:** System Settings → Wi-Fi → Details → IP Address

Or use **Tailscale** for reliable access anywhere:
```bash
brew install --cask tailscale
# Install Tailscale on phone too, use the Tailscale IP instead
```

### 4c. Build and Install the App

```bash
cd flutter_app
flutter pub get
flutter run  # with your Samsung phone connected via USB
```

Or build an APK:
```bash
flutter build apk --release
# Install: adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Step 5: Connect Amazfit Heliostrap to Health Connect

1. Open the **Zepp** app on your phone
2. Go to **Profile → Connected Apps → Health Connect**
3. Enable sync (steps, heart rate, sleep, HRV)
4. Open **Health Connect** (Settings → Apps → Health Connect)
5. Verify Zepp has read/write permission

After connecting, data flows: **Zepp → Health Connect → ILM app → Backend**

---

## Step 6: Grant Screen Time Permission

Samsung: **Settings → Apps → ⋮ (3 dots) → Special App Access → Usage Access**
→ Find "Life Manager" → Toggle on

This allows the app to read per-app usage stats.

---

## Step 7: Set Up Firebase Push Notifications (Optional)

> Skip this initially. The app works without push notifications.

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project
3. Add an Android app with package name `com.ilm.app`
4. Download `google-services.json` → place in `flutter_app/android/app/`
5. Download service account JSON → place in `backend/firebase-service-account.json`
6. Set `FIREBASE_CREDENTIALS_PATH=./firebase-service-account.json` in `backend/.env`

---

## Daily Operation

### Mac (backend)
```bash
cd backend && source venv/bin/activate && python3 run.py
```
> Tip: Add this to your login items or create a launchd service to auto-start.

### Automatic AI Summaries Schedule
| Time | Summary |
|---|---|
| **07:00** daily | Morning briefing (what's ahead today) |
| **23:00** daily | Daily recap (how today went) |
| **Sunday 22:00** | Weekly recap + next week briefing |
| **1st of month** | Monthly recap + month ahead briefing |

### Manual Generation
Via web dashboard → **AI Summaries** → choose type → **Generate Now**

Or via API:
```bash
curl -H "X-Device-Token: your-token" -H "Content-Type: application/json" \
  -X POST http://localhost:8000/api/v1/summaries/generate \
  -d '{"type": "daily_recap"}'
```

---

## Troubleshooting

**Backend won't start?**
```bash
source venv/bin/activate
python3 -c "from app.main import app; print('OK')"
```

**App can't reach backend?**
- Check Mac and phone are on the same WiFi
- Check your IP in constants.dart matches `ifconfig | grep "inet "`
- Or use Tailscale

**No health data showing?**
- Open app → Health tab → tap Sync button
- Check Health Connect → Zepp has permission
- Check Zepp app has synced with the watch recently

**Ollama slow?**
- `mistral:7b-instruct` takes 15-30s on M1/M2/M3 — that's normal
- For faster results: `ollama pull llama3.2:3b` and change `PREFERRED_AI_MODEL` in .env

**No AI summaries?**
- Ensure Ollama is running: `curl http://localhost:11434/api/tags`
- Check backend logs for Ollama errors
- Or set `CLAUDE_API_KEY` in .env to use Claude as fallback

---

## API Quick Reference

All endpoints require header: `X-Device-Token: your-token`

```
GET  /api/v1/dashboard/today          → today's summary
GET  /api/v1/tasks                    → all tasks
POST /api/v1/tasks                    → create task
POST /api/v1/habits/{id}/log          → mark habit done
POST /api/v1/summaries/generate       → generate AI summary now
GET  /api/v1/summaries/latest?type=daily_briefing → latest briefing
POST /api/v1/health/sync              → sync health data from phone
GET  /api/v1/screen-time/daily        → today's screen time
```

Full interactive docs: **http://localhost:8000/docs**
