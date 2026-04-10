# ILM V2 — Claude Code Übergabe-Prompt

Diesen Prompt in das ILM-Repo auf dem Mac Mini in Claude Code einfügen.

---

## Prompt (vollständig kopieren):

```
Du hilfst mir dabei, den Integrated Life Manager (ILM) in eine stabile, vollständig funktionierende Version 2 zu bringen. Das Projekt existiert bereits — du arbeitest im vorhandenen Repo. Lies zuerst CLAUDE.md und die wichtigsten Dateien bevor du irgendetwas änderst.

---

## Kontext

ILM ist ein persönliches Produktivitätssystem mit:
- FastAPI Backend (Python 3.12, async SQLAlchemy, SQLite)
- React/TypeScript Web-Dashboard (Vite, TanStack Query, Tailwind)
- Flutter Android App (Riverpod, GoRouter, Hive, Firebase)
- APScheduler für automatische KI-Briefings (07:00) und Recaps (23:00)
- Zepp Cloud API Integration für Amazfit Smartwatch-Daten
- Firebase Cloud Messaging für Push-Benachrichtigungen

Das System war in V1 nie stabil. Alle Services sind aktuell gestoppt. Ich will eine robuste V2 — keine neuen Features, nur alles funktioniert zuverlässig.

---

## Was sich in V2 ändert

### 1. KI-Architektur (wichtigste Änderung)

Die KI-Cascade in `ai_service.py` wird umgebaut:

**Alt (V1):** OpenClaw → Ollama (mistral:7b) → Claude API
**Neu (V2):** OpenClaw (neu gebaut) → Claude API (Anthropic)

Ollama wird nicht mehr verwendet. Die neue Logik:
- **OpenClaw**: Lokaler leichtgewichtiger Agent für repetitive, geplante Jobs (Briefing 07:00, Recap 23:00). Empfängt strukturierte JSON-Anfragen, leitet an ein konfigurierbares Modell weiter.
- **Claude API**: Für komplexe Chat-Anfragen, direkte Nutzerfragen, alles was echtes Reasoning braucht.

### 2. Zepp-Daten (kritisches Problem aus V1)

Das Amazfit Band synct über die Zepp-App auf dem Handy. Gesundheitsdaten (Steps, Heart Rate, Sleep) sollen vom Backend direkt über die **Zepp Cloud API** abgerufen werden — nicht über Health Connect (Health Connect funktioniert nicht mit Sideloaded APKs).

`zepp_service.py` ist vorhanden, hat aber in V1 nie stabil funktioniert. Der Zepp-Sync muss komplett debuggt und zum Laufen gebracht werden.

### 3. Alles andere bleibt wie in V1

Keine neuen Features. Alle bestehenden Router, Models, Schemas bleiben unverändert — außer sie müssen repariert werden.

---

## Aufgaben in Reihenfolge

### Phase 0 — Zustand prüfen

1. CLAUDE.md lesen
2. Alle wichtigen Dateien lesen: `backend/app/main.py`, `backend/app/services/ai_service.py`, `backend/app/services/zepp_service.py`, `backend/jobs/scheduler.py`
3. `.env.example` lesen — verstehen welche Keys benötigt werden
4. Prüfen: Ist `backend/venv/` vorhanden? Falls ja: `pip install -r requirements.txt` ausführen. Falls nein: neu anlegen.
5. Backend starten: `cd backend && source venv/bin/activate && python run.py`
6. Fehler dokumentieren und Priorität setzen

### Phase 1 — Backend reparieren

1. Alle Startup-Fehler beheben (fehlende Dependencies, Schema-Konflikte, Imports)
2. Backend muss starten ohne Fehler: `http://localhost:8000/docs` muss erreichbar sein
3. Alle 11 Router testen via Swagger: tasks, habits, health, screen_time, journal, summaries, chat, events, planner, dashboard, reminders
4. Fehler in Routers oder Services beheben

### Phase 2 — Zepp-Sync reparieren

1. `zepp_service.py` komplett lesen und verstehen
2. `POST /api/v1/health/zepp-sync` manuell aufrufen
3. Fehler analysieren — API-Responses loggen
4. Zepp Cloud API debuggen bis echte Daten (Steps, Heart Rate, Sleep) in die DB kommen
5. Automatischen Sync-Job (alle 4h in scheduler.py) testen

**Hinweis:** Die Zepp Cloud API ist eine inoffizielle API. Falls die aktuelle Implementierung veraltet ist, nach aktuellen Zepp API Endpoints suchen und `zepp_service.py` anpassen. Credentials kommen aus `.env` (ZEPP_EMAIL, ZEPP_PASSWORD).

### Phase 3 — KI-Cascade umbauen

1. `ai_service.py` lesen
2. Cascade umbauen: Ollama-Aufrufe entfernen (nicht löschen, auskommentieren)
3. Neue Cascade: OpenClaw (lokal) → Claude API (Fallback)
4. OpenClaw als separaten lokalen Service aufbauen (neues Python-Script oder FastAPI-Instanz auf anderem Port):
   - Empfängt POST-Anfragen mit strukturiertem Kontext (JSON)
   - Generiert Text-Response für Briefings/Recaps
   - Nutzt ein konfigurierbares Modell (zunächst: Claude API mit günstigstem Modell, z.B. claude-haiku-4-5-20251001)
   - Antwortet als einfacher HTTP-Service
5. `ai_service.py` so anpassen dass OpenClaw zuerst versucht wird, Claude API als Fallback für Chat
6. Claude API direkt (ohne OpenClaw-Umweg) für `POST /api/v1/chat/message` — dort kommt komplexes Reasoning vom Nutzer

**OpenClaw Prompt-Vorlage für Briefing:**
```
Du bist ein persönlicher Assistent. Erstelle ein Morgen-Briefing auf Basis dieser Daten:
- Aufgaben heute: {tasks}
- Gewohnheiten offen: {habits}
- Gesundheit gestern: {health_summary}
- Schlaf: {sleep}
Kompakt, motivierend, max. 150 Wörter. Auf Deutsch.
```

**OpenClaw Prompt-Vorlage für Recap:**
```
Du bist ein persönlicher Assistent. Erstelle einen Tages-Recap:
- Erledigte Aufgaben: {completed_tasks}
- Gewohnheiten: {habit_completions}
- Schritte heute: {steps}
- Screen Time: {screen_time_summary}
Ehrlich, kurz, max. 150 Wörter. Auf Deutsch.
```

### Phase 4 — Scheduler testen

1. `jobs/scheduler.py` lesen — alle Jobs vorhanden?
2. APScheduler starten (läuft mit dem Backend)
3. Briefing-Job manuell triggern: `POST /api/v1/summaries/generate`
4. Prüfen ob Summary in DB gespeichert wird
5. Firebase-Notifications testen (falls Firebase-Key vorhanden)

### Phase 5 — Web-Dashboard

1. `cd web_dashboard && npm install`
2. `npm run dev` — Dev-Server auf `:5173`
3. Alle Pages durchklicken: Tasks, Habits, Health, Journal, Chat, Summaries
4. Fehler fixen (fehlende API-Felder, TypeScript-Errors, API-Verbindungsprobleme)
5. Für Produktion: `npm run build` (baut nach `../backend/static/`)

### Phase 6 — Flutter App

1. `cd flutter_app && flutter pub get`
2. `lib/config/constants.dart` — Backend-URL auf Mac Mini IP setzen (nicht localhost — muss von Handy erreichbar sein, z.B. `192.168.x.x:8000`)
3. Bekanntes Problem: Health Connect funktioniert nicht mit Sideloaded APKs. **Lösung für V2:** Gesundheitsdaten kommen vom Backend (Zepp Cloud), nicht von Health Connect. Health Connect in der App deaktivieren oder Fehler graceful abfangen.
4. `flutter build apk --release`
5. `adb install build/app/outputs/flutter-apk/app-release.apk`
6. App testen: Tasks, Habits, Chat, Push-Notifications

### Phase 7 — Stabilität & Cleanup

1. `.env.example` aktualisieren (alle Keys dokumentieren, keine echten Werte)
2. Sicherstellen dass `.env` in `.gitignore` ist
3. Backend als Daemon einrichten (launchd auf Mac Mini) damit es beim Systemstart automatisch läuft
4. Test-Durchlauf: 24h Betrieb simulieren (Zepp-Sync, Briefing, Recap, Chat)

---

## Kritische technische Randbedingungen

- **Python:** Immer `backend/venv/` verwenden. System-Python auf dem Mac ist möglicherweise 3.14 — inkompatibel mit manchen Wheels. `backend/venv/` ist Python 3.12.
- **Async:** Alle DB-Operationen sind async (`AsyncSession`). Nie sync SQLAlchemy verwenden.
- **SQLAlchemy:** `Float` verwenden, nicht `Real` für Float-Spalten.
- **Schemas vs. Models:** Pydantic-Schemas in `backend/app/schemas/` sind von SQLAlchemy-Models in `backend/app/models/` getrennt. Nicht vermischen.
- **Static Files:** Web-Dashboard muss gebaut sein (`npm run build`) bevor FastAPI es serven kann. Im Dev-Modus: Dashboard läuft auf `:5173` (Vite-Proxy zum Backend).
- **Auth:** Alle API-Endpoints (außer `/docs`, `/health`, `/static`) brauchen `X-Device-Token` Header aus `.env`.
- **Flutter Backend-URL:** Für Tests auf echtem Android-Gerät muss die IP des Mac Mini im lokalen Netzwerk verwendet werden, nicht `localhost`.

---

## Erwartetes Ergebnis

Am Ende dieser Arbeit:
- Backend läuft stabil auf dem Mac Mini, startet automatisch
- Zepp-Daten (Steps, Schlaf, Herzfrequenz) kommen alle 4h rein
- KI-Briefing um 07:00 und Recap um 23:00 werden generiert und gespeichert
- Web-Dashboard ist vollständig nutzbar
- Flutter-App verbindet sich, Chat und Benachrichtigungen funktionieren
- `.env` enthält alle Keys, ist aus Git ausgeschlossen
- GitHub-Repo ist bereit für Veröffentlichung (keine Secrets im Code)

Fang mit Phase 0 an. Lies alle relevanten Dateien bevor du irgendwas änderst.
```
