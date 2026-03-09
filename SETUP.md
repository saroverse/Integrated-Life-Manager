# Integrated Life Manager — Setup Guide

## Step 1: Start the backend

The backend is the central hub. Start this first and keep it running.

```bash
cd "/path/to/Integrated Life Manager/backend"

# First time only: fill in your credentials
# Edit .env — set DEVICE_API_TOKEN, ZEPP_EMAIL, ZEPP_PASSWORD

# Activate the Python 3.12 virtual environment
source venv/bin/activate

# Start the server
python3 run.py
```

The server starts at **<http://localhost:8000>**
API docs: **<http://localhost:8000/docs>**

---

## Step 2: Install Ollama (local AI)

```bash
brew install ollama

# Pull the AI model (~4 GB)
ollama pull mistral:7b-instruct

# Start Ollama (keep running alongside the backend)
ollama serve
```

Once running, the backend uses it for AI summaries and chat. Test it:

```bash
curl -H "X-Device-Token: your-token" \
     -H "Content-Type: application/json" \
     -X POST http://localhost:8000/api/v1/summaries/generate \
     -d '{"type": "daily_briefing"}'
```

**Ollama slow?**
`mistral:7b-instruct` takes 15–30 s on M1/M2/M3 — that's normal. For faster results: `ollama pull llama3.2:3b` and set `PREFERRED_AI_MODEL=llama3.2:3b` in `.env`.

---

## Step 3: Set up Zepp health sync

Add your Zepp account credentials to `backend/.env`:

```env
ZEPP_EMAIL=your@email.com
ZEPP_PASSWORD=yourpassword
```

Restart the backend. Health data (steps, sleep, heart rate) is then fetched automatically every 4 hours.

To trigger a manual sync immediately:

- Open `http://localhost:8000/docs` → `POST /api/v1/health/zepp-sync` → Execute

---

## Step 4: Set up the Android app (optional)

### 4a. Install Flutter

```bash
brew install --cask flutter
flutter doctor  # check setup
```

### 4b. Configure the backend URL

Edit `flutter_app/lib/config/constants.dart`:

```dart
static const String backendUrl = 'http://192.168.1.100:8000';  // ← your Mac's local IP
static const String deviceToken = 'your-token-here';           // ← same as DEVICE_API_TOKEN in .env
```

**Find your Mac's IP:** System Settings → Wi-Fi → Details → IP Address

For access outside the home network, use **Tailscale**:

```bash
brew install --cask tailscale
# Install Tailscale on the phone too — use the Tailscale IP instead
```

### 4c. Build and install

```bash
cd flutter_app
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## Step 5: Grant Android screen time permission

**Settings → Apps → ⋮ → Special App Access → Usage Access** → find "Life Manager" → toggle on

This allows the app to read per-app usage stats and sync them to the backend.

---

## Step 6: Set up Firebase push notifications (optional)

> Skip this initially — the app works without push notifications.

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a project → Add Android app with package name `com.ilm.app`
3. Download `google-services.json` → place in `flutter_app/android/app/`
4. Download service account JSON → place in `backend/firebase-service-account.json`
5. Set `FIREBASE_CREDENTIALS_PATH=./firebase-service-account.json` in `backend/.env`

---

## Daily operation

```bash
# Start everything
ollama serve &
cd "/path/to/Integrated Life Manager/backend"
source venv/bin/activate && python3 run.py
```

> Tip: Add to macOS login items or create a launchd service to auto-start.

### Automatic schedule

| Time | Job |
| --- | --- |
| **07:00** daily | Morning briefing |
| **23:00** daily | Daily recap |
| **Sunday 22:00** | Weekly recap |
| **1st of month 00:30** | Monthly recap |
| **Every 4 hours** | Zepp health sync |
| **Every minute** | Reminder check + push |

### Manual AI summary generation

Via web dashboard → **AI Summaries** → choose type → **Generate Now**

Or via API:

```bash
curl -H "X-Device-Token: your-token" \
     -H "Content-Type: application/json" \
     -X POST http://localhost:8000/api/v1/summaries/generate \
     -d '{"type": "daily_recap"}'
```

---

## Troubleshooting

### Backend won't start

```bash
source venv/bin/activate
python3 -c "from app.main import app; print('OK')"
```

### Port already in use

```bash
lsof -ti:8000 | xargs kill -9
```

### App can't reach the backend

- Confirm Mac and phone are on the same Wi-Fi
- Check the IP in `constants.dart` matches `ifconfig | grep "inet "`
- Or use Tailscale

### No health data showing

- Check `ZEPP_EMAIL` / `ZEPP_PASSWORD` are set correctly in `.env`
- Trigger a manual sync: `/docs` → `POST /api/v1/health/zepp-sync`
- Check backend logs for auth errors

### No AI summaries

- Confirm Ollama is running: `curl http://localhost:11434/api/tags`
- Check backend logs for errors
- Or set `CLAUDE_API_KEY` in `.env` to use Claude as fallback
