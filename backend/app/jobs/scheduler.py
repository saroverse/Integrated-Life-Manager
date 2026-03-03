import logging
from datetime import date, datetime, timedelta, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import select

from app.config import settings
from app.database import AsyncSessionLocal
from app.models.reminder import AppSetting, Reminder
from app.services import summary_service
from app.services.notification_service import send_push

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler(timezone=settings.timezone)


async def _run_daily_briefing():
    logger.info("Running daily briefing generation")
    async with AsyncSessionLocal() as db:
        try:
            summary = await summary_service.generate_daily_briefing(db)
            logger.info(f"Daily briefing generated: {summary.id}")
        except Exception:
            logger.exception("Failed to generate daily briefing")


async def _run_daily_recap():
    logger.info("Running daily recap generation")
    async with AsyncSessionLocal() as db:
        try:
            summary = await summary_service.generate_daily_recap(db)
            logger.info(f"Daily recap generated: {summary.id}")
        except Exception:
            logger.exception("Failed to generate daily recap")


async def _run_weekly_recap():
    logger.info("Running weekly recap generation")
    today = date.today()
    week_start = (today - timedelta(days=today.weekday())).isoformat()
    async with AsyncSessionLocal() as db:
        try:
            summary = await summary_service.generate_weekly_recap(db, week_start)
            logger.info(f"Weekly recap generated: {summary.id}")
        except Exception:
            logger.exception("Failed to generate weekly recap")


async def _run_monthly_recap():
    logger.info("Running monthly recap generation")
    today = date.today()
    # Run for the previous month (called on 1st of new month)
    prev_month = (today.replace(day=1) - timedelta(days=1)).replace(day=1)
    async with AsyncSessionLocal() as db:
        try:
            summary = await summary_service.generate_monthly_recap(db, prev_month.isoformat())
            logger.info(f"Monthly recap generated: {summary.id}")
        except Exception:
            logger.exception("Failed to generate monthly recap")


async def _run_reminder_check():
    now = datetime.now(timezone.utc).isoformat()
    async with AsyncSessionLocal() as db:
        try:
            q = select(Reminder).where(Reminder.status == "pending", Reminder.scheduled_at <= now)
            due = (await db.execute(q)).scalars().all()
            if not due:
                return

            token_setting = await db.get(AppSetting, "fcm_device_token")
            token = token_setting.value if token_setting else None

            for reminder in due:
                await send_push(
                    reminder.title,
                    reminder.body or "",
                    token,
                    {"type": "reminder", "id": reminder.id},
                )
                reminder.status = "sent"
                reminder.sent_at = datetime.now(timezone.utc).isoformat()

            await db.commit()
            logger.info(f"Sent {len(due)} reminder(s)")
        except Exception:
            logger.exception("Failed to process reminders")


def setup_scheduler():
    scheduler.add_job(_run_daily_briefing, "cron", hour=7, minute=0, id="daily_briefing")
    scheduler.add_job(_run_daily_recap, "cron", hour=23, minute=0, id="daily_recap")
    scheduler.add_job(_run_weekly_recap, "cron", day_of_week="sun", hour=22, minute=0, id="weekly_recap")
    scheduler.add_job(_run_monthly_recap, "cron", day=1, hour=0, minute=30, id="monthly_recap")
    scheduler.add_job(_run_reminder_check, "interval", minutes=1, id="reminder_check")
    logger.info("Scheduler jobs configured")
