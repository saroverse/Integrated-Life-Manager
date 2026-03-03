from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.summary import Summary
from app.schemas.summary import SummaryGenerateRequest, SummaryResponse
from app.services import summary_service

router = APIRouter(prefix="/summaries", tags=["summaries"])

VALID_TYPES = {
    "daily_recap",
    "daily_briefing",
    "weekly_recap",
    "weekly_briefing",
    "monthly_recap",
    "monthly_briefing",
}


@router.get("", response_model=list[SummaryResponse])
async def list_summaries(
    type: str | None = None,
    limit: int = 10,
    db: AsyncSession = Depends(get_db),
):
    q = select(Summary)
    if type:
        q = q.where(Summary.summary_type == type)
    q = q.order_by(Summary.created_at.desc()).limit(limit)
    result = await db.execute(q)
    return result.scalars().all()


@router.get("/latest", response_model=SummaryResponse | None)
async def get_latest_summary(type: str = "daily_briefing", db: AsyncSession = Depends(get_db)):
    q = select(Summary).where(Summary.summary_type == type, Summary.status == "ready").order_by(
        Summary.created_at.desc()
    )
    result = await db.execute(q)
    return result.scalar_one_or_none()


@router.get("/{summary_id}", response_model=SummaryResponse)
async def get_summary(summary_id: str, db: AsyncSession = Depends(get_db)):
    summary = await db.get(Summary, summary_id)
    if not summary:
        raise HTTPException(404, "Summary not found")
    return summary


@router.post("/generate", response_model=SummaryResponse)
async def generate_summary(data: SummaryGenerateRequest, db: AsyncSession = Depends(get_db)):
    if data.type not in VALID_TYPES:
        raise HTTPException(400, f"Invalid type. Must be one of: {', '.join(VALID_TYPES)}")

    target_date = data.date or date.today().isoformat()

    try:
        if data.type == "daily_recap":
            summary = await summary_service.generate_daily_recap(db, target_date)
        elif data.type == "daily_briefing":
            summary = await summary_service.generate_daily_briefing(db, target_date)
        elif data.type == "weekly_recap":
            summary = await summary_service.generate_weekly_recap(db, target_date)
        elif data.type == "monthly_recap":
            summary = await summary_service.generate_monthly_recap(db, target_date)
        else:
            raise HTTPException(400, f"Type '{data.type}' not yet implemented")
    except Exception as e:
        raise HTTPException(500, f"AI generation failed: {str(e)}")

    return summary
