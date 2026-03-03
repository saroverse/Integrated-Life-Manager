from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.health import HealthMetric, SleepSession, Workout
from app.schemas.health import HealthSyncPayload, HealthMetricResponse, SleepSessionResponse

router = APIRouter(prefix="/health", tags=["health"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.post("/sync", status_code=200)
async def sync_health_data(payload: HealthSyncPayload, db: AsyncSession = Depends(get_db)):
    synced_at = _now()
    metrics_upserted = 0
    sleep_upserted = 0
    workouts_upserted = 0

    for m in payload.metrics:
        existing = await db.get(HealthMetric, m.id)
        if existing:
            existing.value = m.value
            existing.synced_at = synced_at
        else:
            db.add(HealthMetric(**m.model_dump(), synced_at=synced_at))
            metrics_upserted += 1

    for s in payload.sleep_sessions:
        existing = await db.get(SleepSession, s.id)
        if existing:
            for field, value in s.model_dump(exclude_none=True).items():
                setattr(existing, field, value)
            existing.synced_at = synced_at
        else:
            db.add(SleepSession(**s.model_dump(), synced_at=synced_at))
            sleep_upserted += 1

    for w in payload.workouts:
        from app.models.health import Workout as WorkoutModel
        existing = await db.get(WorkoutModel, w.id)
        if not existing:
            db.add(WorkoutModel(**w.model_dump(), synced_at=synced_at))
            workouts_upserted += 1

    await db.commit()
    return {"metrics": metrics_upserted, "sleep": sleep_upserted, "workouts": workouts_upserted}


@router.get("/summary")
async def get_health_summary(date: str | None = None, db: AsyncSession = Depends(get_db)):
    if not date:
        date = datetime.now(timezone.utc).date().isoformat()

    # Fetch aggregated metrics for the day
    result = {}
    for metric_type in ["steps", "heart_rate", "resting_heart_rate", "heart_rate_variability_sdnn", "weight", "blood_oxygen"]:
        q = select(func.avg(HealthMetric.value)).where(
            HealthMetric.metric_type == metric_type,
            HealthMetric.date == date,
        )
        avg = (await db.execute(q)).scalar()

        if metric_type == "steps":
            q_sum = select(func.sum(HealthMetric.value)).where(
                HealthMetric.metric_type == metric_type,
                HealthMetric.date == date,
            )
            result["steps"] = (await db.execute(q_sum)).scalar() or 0
        else:
            result[metric_type] = round(avg, 1) if avg else None

    # Sleep session for the day
    sleep_q = select(SleepSession).where(SleepSession.date == date)
    sleep_result = await db.execute(sleep_q)
    sleep = sleep_result.scalar_one_or_none()
    result["sleep"] = {
        "total": sleep.total_duration,
        "deep": sleep.deep_sleep,
        "rem": sleep.rem_sleep,
        "light": sleep.light_sleep,
        "score": sleep.sleep_score,
        "bedtime": sleep.bedtime,
        "wake_time": sleep.wake_time,
    } if sleep else None

    # Workouts
    workout_q = select(Workout).where(Workout.date == date)
    workout_result = await db.execute(workout_q)
    workouts = workout_result.scalars().all()
    result["workouts"] = [
        {"type": w.workout_type, "duration": w.duration, "calories": w.calories}
        for w in workouts
    ]

    return {"date": date, **result}


@router.get("/sleep")
async def get_sleep_sessions(
    start: str | None = None,
    end: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    q = select(SleepSession)
    if start:
        q = q.where(SleepSession.date >= start)
    if end:
        q = q.where(SleepSession.date <= end)
    q = q.order_by(SleepSession.date.desc())
    result = await db.execute(q)
    return result.scalars().all()


@router.get("/metrics")
async def get_metrics(
    type: str | None = None,
    start: str | None = None,
    end: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    q = select(HealthMetric)
    if type:
        q = q.where(HealthMetric.metric_type == type)
    if start:
        q = q.where(HealthMetric.date >= start)
    if end:
        q = q.where(HealthMetric.date <= end)
    q = q.order_by(HealthMetric.recorded_at.desc())
    result = await db.execute(q)
    return result.scalars().all()


@router.get("/workouts")
async def get_workouts(
    start: str | None = None,
    end: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    q = select(Workout)
    if start:
        q = q.where(Workout.date >= start)
    if end:
        q = q.where(Workout.date <= end)
    q = q.order_by(Workout.date.desc())
    result = await db.execute(q)
    return result.scalars().all()
