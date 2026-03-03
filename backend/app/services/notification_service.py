import asyncio
import logging
import os

logger = logging.getLogger(__name__)

_firebase_app = None
_firebase_available = False
_init_attempted = False


def _init_firebase() -> bool:
    global _firebase_app, _firebase_available, _init_attempted
    if _init_attempted:
        return _firebase_available
    _init_attempted = True

    creds_path = os.environ.get("FIREBASE_CREDENTIALS_PATH", "./firebase-service-account.json")
    if not os.path.isfile(creds_path):
        logger.warning(
            "Firebase credentials not found at '%s' — push notifications disabled. "
            "Place your Firebase service account JSON there to enable them.",
            creds_path,
        )
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(creds_path)
        _firebase_app = firebase_admin.initialize_app(cred)
        _firebase_available = True
        logger.info("Firebase initialized — push notifications enabled.")
        return True
    except Exception:
        logger.exception("Failed to initialize Firebase — push notifications disabled.")
        return False


def _send_sync(title: str, body: str, token: str, data: dict) -> None:
    from firebase_admin import messaging

    msg = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in data.items()},
        token=token,
    )
    messaging.send(msg)


async def send_push(title: str, body: str, token: str | None, data: dict | None = None) -> bool:
    """Send a push notification to the device. Returns True on success."""
    if not token:
        logger.debug("No FCM token registered — skipping push notification.")
        return False
    if not _init_firebase():
        return False
    try:
        await asyncio.to_thread(_send_sync, title, body, token, data or {})
        logger.info("Push notification sent: '%s'", title)
        return True
    except Exception:
        logger.exception("Failed to send push notification '%s'", title)
        return False
