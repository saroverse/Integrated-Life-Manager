"""Zepp/Huami cloud API integration.

V2: Uses a static app_token + user_id extracted from the Zepp app (via mitmproxy).
This bypasses the broken/rate-limited login endpoint entirely.

Data flow:
  Amazfit watch → Zepp cloud → this service (runs on Mac Mini) → SQLite

Setup:
  1. Set ZEPP_APP_TOKEN and ZEPP_USER_ID in backend/.env
     (extract with mitmproxy — see docs below)
  2. Token lasts ~90 days; refresh by re-extracting when expired

Extraction steps:
  1. pip install mitmproxy && mitmproxy --listen-port 8080
  2. Set phone WiFi proxy → Mac-IP:8080
  3. Visit mitm.it on phone, install certificate
  4. Open Zepp app, navigate to health/steps screen
  5. Find request to api-mifit.huami.com in mitmproxy
  6. Copy 'apptoken' header value → ZEPP_APP_TOKEN
  7. Copy 'userid' query param → ZEPP_USER_ID
"""

import base64
import json
import logging
from datetime import date, datetime, timedelta, timezone

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.health import HealthMetric, SleepSession

logger = logging.getLogger(__name__)


def _mins_to_hours(minutes: int | float | None) -> float | None:
    if not minutes:
        return None
    return round(minutes / 60.0, 2)


def _decode_summary(b64: str) -> dict:
    """Base64-decode and JSON-parse a Zepp summary blob. Returns {} on failure."""
    try:
        decoded = base64.b64decode(b64).decode("utf-8", errors="replace")
        return json.loads(decoded)
    except Exception as e:
        logger.debug(f"Could not decode summary blob: {e}  raw={b64[:80]!r}")
        return {}


async def fetch_and_store(db: AsyncSession, days_back: int = 3) -> dict:
    """
    Pull health data from Zepp cloud for the last `days_back` days and upsert
    into the local DB.  Returns {"metrics_saved": N, "sleep_saved": N, ...}.

    Requires ZEPP_APP_TOKEN and ZEPP_USER_ID in backend/.env
    """
    app_token = settings.zepp_app_token
    user_id = settings.zepp_user_id

    if not app_token or not user_id:
        raise RuntimeError(
            "ZEPP_APP_TOKEN and ZEPP_USER_ID must be set in backend/.env.\n"
            "Extract them from the Zepp app using mitmproxy (see zepp_service.py docs)."
        )

    today = date.today()
    from_date = (today - timedelta(days=days_back)).isoformat()
    to_date = today.isoformat()

    metrics_saved = 0
    sleep_saved = 0
    synced_at = datetime.now(timezone.utc).isoformat()

    async with httpx.AsyncClient(timeout=30.0) as client:
        headers = {
            "apptoken": app_token,
            "appPlatform": "android",
            "appname": "com.huami.midong",
            "appVersion": "6.3.0",
        }

        r = await client.get(
            "https://api-mifit-de2.zepp.com/v1/data/band_data.json",
            headers=headers,
            params={
                "query_type": "summary",
                "device_type": "androids",
                "userid": user_id,
                "from_date": from_date,
                "to_date": to_date,
            },
        )

        if r.status_code == 401:
            raise RuntimeError(
                "Zepp token expired or invalid (401). "
                "Re-extract ZEPP_APP_TOKEN and ZEPP_USER_ID from the Zepp app using mitmproxy."
            )

        r.raise_for_status()
        resp_body = r.json()
        logger.debug(f"Zepp raw response keys: {list(resp_body.keys())}")

        # API returns: {"code": 1, "data": [...list of daily entries...]}
        # Each entry has "date_time" (YYYY-MM-DD) and "summary" (base64 JSON)
        data = resp_body.get("data", [])
        if not isinstance(data, list):
            data = []
        if not data:
            logger.info(f"Zepp returned no data for {from_date}–{to_date}")
            return {"metrics_saved": 0, "sleep_saved": 0, "from": from_date, "to": to_date}

        for entry in data:
            raw_date = str(entry.get("date_time", ""))
            # date_time comes as "YYYY-MM-DD"; legacy format "YYYYMMDD" handled too
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

            # ---- Resting heart rate ----
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
                st = slp.get("st")
                ed = slp.get("ed")
                dp = slp.get("dp", 0) or 0
                rm = slp.get("rm", 0) or slp.get("wk2", 0) or 0
                lt = slp.get("lt", 0) or 0
                wk = slp.get("wk", 0) or 0
                sc = slp.get("sc")

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
