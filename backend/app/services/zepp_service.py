"""Zepp/Huami cloud API integration.

Authenticates with Zepp's servers using the unofficial Huami API and fetches
health data (steps, sleep, resting heart rate) for storage in the local DB.

This bypasses Health Connect entirely — data flows:
  Amazfit watch → Zepp cloud → this service (runs on Mac Mini) → SQLite

Requires ZEPP_EMAIL and ZEPP_PASSWORD in backend/.env
"""

import base64
import json
import logging
import time
import urllib.parse
import uuid
from datetime import date, datetime, timedelta, timezone

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.health import HealthMetric, SleepSession

logger = logging.getLogger(__name__)

# Token cache — in-memory only; re-auth happens automatically on restart (takes ~1 s)
_cached_token: str | None = None
_cached_user_id: str | None = None
_token_expiry: float = 0


def _device_id() -> str:
    """Stable pseudo-device-ID derived from email (UUID3)."""
    return str(uuid.uuid3(uuid.NAMESPACE_DNS, settings.zepp_email or "ilm-default"))


async def _authenticate() -> tuple[str, str]:
    """Authenticate with Zepp and return (app_token, user_id). Cached for 23 h."""
    global _cached_token, _cached_user_id, _token_expiry

    if _cached_token and time.time() < _token_expiry:
        return _cached_token, _cached_user_id  # type: ignore[return-value]

    email = settings.zepp_email
    password = settings.zepp_password
    if not email or not password:
        raise RuntimeError("ZEPP_EMAIL and ZEPP_PASSWORD must be configured in backend/.env")

    async with httpx.AsyncClient(timeout=30.0) as client:
        # ---- Stage 1: email → redirect with access token ----
        auth_url = f"https://api-user.huami.com/registrations/{urllib.parse.quote(email)}/tokens"
        r1 = await client.post(
            auth_url,
            data={
                "state": "REDIRECTION",
                "client_id": "HuaMi",
                "redirect_uri": "https://s3-us-west-2.amazonws.com/hm-registration/successsignin.html",
                "token": "access",
                "password": password,
            },
            follow_redirects=False,
        )

        location = r1.headers.get("Location", "")
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(location).query)
        access_token = (qs.get("access") or qs.get("token") or [None])[0]

        if not access_token:
            raise RuntimeError(
                f"Zepp auth stage 1 failed — no access token in redirect.\n"
                f"Status: {r1.status_code}  Location: {location!r}\n"
                "Check your ZEPP_EMAIL / ZEPP_PASSWORD in .env"
            )

        # ---- Stage 2: access token → app_token + user_id ----
        r2 = await client.post(
            "https://account.huami.com/v2/client/login",
            data={
                "dn": (
                    "account.huami.com,api-user.huami.com,api-watch.huami.com,"
                    "api-analytics.huami.com,api-mifit.huami.com,"
                    "api-platform-routing.huami.com"
                ),
                "app_version": "6.3.0-play",
                "source": "com.huami.midong",
                "country_code": "DE",
                "device_id": _device_id(),
                "third_name": "huami-zepp",
                "grant_type": "access_token",
                "code": access_token,
                "app_name": "com.huami.midong",
                "allow_registration": "false",
            },
        )
        r2.raise_for_status()
        body = r2.json()

        token_info = body.get("token_info", {})
        app_token = token_info.get("app_token")
        user_id = token_info.get("user_id")

        if not app_token or not user_id:
            raise RuntimeError(f"Zepp auth stage 2 failed — response: {body}")

    _cached_token = app_token
    _cached_user_id = user_id
    _token_expiry = time.time() + 23 * 3600
    logger.info(f"Zepp authenticated, user_id={user_id}")
    return app_token, user_id


def _decode_summary(b64: str) -> dict:
    """Base64-decode and JSON-parse a Zepp summary blob. Returns {} on failure."""
    try:
        decoded = base64.b64decode(b64).decode("utf-8", errors="replace")
        return json.loads(decoded)
    except Exception as e:
        logger.debug(f"Could not decode summary blob: {e}  raw={b64[:80]!r}")
        return {}


def _mins_to_hours(minutes: int | float | None) -> float | None:
    if not minutes:
        return None
    return round(minutes / 60.0, 2)


async def fetch_and_store(db: AsyncSession, days_back: int = 3) -> dict:
    """
    Pull health data from Zepp cloud for the last `days_back` days and upsert
    into the local DB.  Returns {"metrics_saved": N, "sleep_saved": N, ...}.
    """
    app_token, user_id = await _authenticate()

    today = date.today()
    from_date = (today - timedelta(days=days_back)).isoformat()
    to_date = today.isoformat()

    metrics_saved = 0
    sleep_saved = 0
    synced_at = datetime.now(timezone.utc).isoformat()

    async with httpx.AsyncClient(timeout=30.0) as client:
        headers = {"apptoken": app_token}

        r = await client.get(
            "https://api-mifit.huami.com/v1/data/band_data.json",
            headers=headers,
            params={
                "query_type": "summary",
                "device_type": "androids",
                "userid": user_id,
                "from_date": from_date,
                "to_date": to_date,
            },
        )
        r.raise_for_status()
        resp_body = r.json()

        logger.debug(f"Zepp raw response: {resp_body}")

        summaries = resp_body.get("data", {}).get("summary", [])
        if not summaries:
            logger.info(f"Zepp returned no summary data for {from_date}–{to_date}")
            return {"metrics_saved": 0, "sleep_saved": 0, "from": from_date, "to": to_date}

        for entry in summaries:
            # Date may come as "YYYYMMDD" or "YYYY-MM-DD"
            raw_date = str(entry.get("date", ""))
            if len(raw_date) == 8 and "-" not in raw_date:
                date_str = f"{raw_date[:4]}-{raw_date[4:6]}-{raw_date[6:8]}"
            else:
                date_str = raw_date

            summary = _decode_summary(entry.get("summary", ""))
            if not summary:
                logger.warning(f"Empty/undecodable summary for {date_str} — skipping")
                continue

            # ---- Steps ----
            stp = summary.get("stp", {})
            # Field name varies: ttl / total / stp (flat)
            steps = stp.get("ttl") or stp.get("total") or stp.get("steps")
            if not steps and isinstance(summary.get("stp"), (int, float)):
                steps = summary["stp"]
            if steps and int(steps) > 0:
                metric_id = f"zepp_steps_{date_str}"
                existing = await db.get(HealthMetric, metric_id)
                if existing:
                    existing.value = float(steps)
                    existing.synced_at = synced_at
                else:
                    db.add(HealthMetric(
                        id=metric_id,
                        metric_type="steps",
                        value=float(steps),
                        unit="steps",
                        recorded_at=f"{date_str}T12:00:00",
                        date=date_str,
                        source="zepp_cloud",
                        synced_at=synced_at,
                    ))
                    metrics_saved += 1

            # ---- Resting heart rate (sometimes present in summary) ----
            rhr = (
                summary.get("rhr")
                or summary.get("RestingHeartRate")
                or summary.get("hr", {}).get("rhr")
            )
            if rhr and int(rhr) > 0:
                rhr_id = f"zepp_rhr_{date_str}"
                existing = await db.get(HealthMetric, rhr_id)
                if existing:
                    existing.value = float(rhr)
                    existing.synced_at = synced_at
                else:
                    db.add(HealthMetric(
                        id=rhr_id,
                        metric_type="resting_heart_rate",
                        value=float(rhr),
                        unit="bpm",
                        recorded_at=f"{date_str}T12:00:00",
                        date=date_str,
                        source="zepp_cloud",
                        synced_at=synced_at,
                    ))
                    metrics_saved += 1

            # ---- Sleep ----
            slp = summary.get("slp", {})
            if slp:
                st = slp.get("st")   # bedtime unix timestamp (seconds)
                ed = slp.get("ed")   # wake time unix timestamp (seconds)
                dp = slp.get("dp", 0) or 0   # deep sleep (minutes)
                rm = slp.get("rm", 0) or slp.get("wk2", 0) or 0  # REM (minutes, field varies)
                lt = slp.get("lt", 0) or 0   # light sleep (minutes)
                wk = slp.get("wk", 0) or 0   # awake (minutes)
                sc = slp.get("sc")           # sleep score

                if st and ed and ed > st:
                    bedtime = datetime.fromtimestamp(st, tz=timezone.utc).isoformat()
                    wake_time = datetime.fromtimestamp(ed, tz=timezone.utc).isoformat()
                    total_h = (ed - st) / 3600.0

                    sleep_id = f"zepp_sleep_{date_str}"
                    existing = await db.get(SleepSession, sleep_id)
                    if existing:
                        existing.bedtime = bedtime
                        existing.wake_time = wake_time
                        existing.total_duration = round(total_h, 2)
                        existing.deep_sleep = _mins_to_hours(dp)
                        existing.rem_sleep = _mins_to_hours(rm)
                        existing.light_sleep = _mins_to_hours(lt)
                        existing.awake_time = _mins_to_hours(wk)
                        existing.sleep_score = sc
                        existing.synced_at = synced_at
                    else:
                        db.add(SleepSession(
                            id=sleep_id,
                            date=date_str,
                            bedtime=bedtime,
                            wake_time=wake_time,
                            total_duration=round(total_h, 2),
                            deep_sleep=_mins_to_hours(dp),
                            rem_sleep=_mins_to_hours(rm),
                            light_sleep=_mins_to_hours(lt),
                            awake_time=_mins_to_hours(wk),
                            sleep_score=sc,
                            source="zepp_cloud",
                            synced_at=synced_at,
                        ))
                        sleep_saved += 1

    await db.commit()
    logger.info(f"Zepp sync complete: {metrics_saved} metrics, {sleep_saved} sleep sessions saved")
    return {
        "metrics_saved": metrics_saved,
        "sleep_saved": sleep_saved,
        "from": from_date,
        "to": to_date,
    }
