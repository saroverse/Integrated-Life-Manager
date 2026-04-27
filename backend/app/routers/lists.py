import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.list_item import ListItem, UserList

router = APIRouter(prefix="/lists", tags=["lists"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class ListCreate(BaseModel):
    name: str
    icon: str | None = None
    color: str | None = None


class ListUpdate(BaseModel):
    name: str | None = None
    icon: str | None = None
    color: str | None = None


class ItemCreate(BaseModel):
    text: str
    sort_order: int = 0


class ItemUpdate(BaseModel):
    text: str | None = None
    checked: int | None = None
    sort_order: int | None = None


# ── Lists CRUD ────────────────────────────────────────────────────────────────

@router.get("")
async def get_lists(db: AsyncSession = Depends(get_db)):
    q = select(UserList).order_by(UserList.created_at.asc())
    rows = (await db.execute(q)).scalars().all()
    return [_list_dict(r) for r in rows]


@router.post("", status_code=201)
async def create_list(data: ListCreate, db: AsyncSession = Depends(get_db)):
    now = _now()
    ul = UserList(
        id=str(uuid.uuid4()),
        name=data.name,
        icon=data.icon,
        color=data.color,
        created_at=now,
        updated_at=now,
    )
    db.add(ul)
    await db.commit()
    await db.refresh(ul)
    return _list_dict(ul)


@router.put("/{list_id}")
async def update_list(list_id: str, data: ListUpdate, db: AsyncSession = Depends(get_db)):
    ul = await db.get(UserList, list_id)
    if not ul:
        raise HTTPException(404, "List not found")
    if data.name is not None:
        ul.name = data.name
    if data.icon is not None:
        ul.icon = data.icon
    if data.color is not None:
        ul.color = data.color
    ul.updated_at = _now()
    await db.commit()
    await db.refresh(ul)
    return _list_dict(ul)


@router.delete("/{list_id}", status_code=204)
async def delete_list(list_id: str, db: AsyncSession = Depends(get_db)):
    ul = await db.get(UserList, list_id)
    if not ul:
        raise HTTPException(404, "List not found")
    # cascade-delete items
    items_q = select(ListItem).where(ListItem.list_id == list_id)
    items = (await db.execute(items_q)).scalars().all()
    for item in items:
        await db.delete(item)
    await db.delete(ul)
    await db.commit()


# ── Items CRUD ────────────────────────────────────────────────────────────────

@router.get("/{list_id}/items")
async def get_items(list_id: str, db: AsyncSession = Depends(get_db)):
    ul = await db.get(UserList, list_id)
    if not ul:
        raise HTTPException(404, "List not found")
    q = (
        select(ListItem)
        .where(ListItem.list_id == list_id)
        .order_by(ListItem.checked.asc(), ListItem.sort_order.asc(), ListItem.created_at.asc())
    )
    rows = (await db.execute(q)).scalars().all()
    return [_item_dict(r) for r in rows]


@router.post("/{list_id}/items", status_code=201)
async def add_item(list_id: str, data: ItemCreate, db: AsyncSession = Depends(get_db)):
    ul = await db.get(UserList, list_id)
    if not ul:
        raise HTTPException(404, "List not found")
    now = _now()
    item = ListItem(
        id=str(uuid.uuid4()),
        list_id=list_id,
        text=data.text,
        checked=0,
        sort_order=data.sort_order,
        created_at=now,
    )
    db.add(item)
    ul.updated_at = now
    await db.commit()
    await db.refresh(item)
    return _item_dict(item)


@router.put("/{list_id}/items/{item_id}")
async def update_item(
    list_id: str, item_id: str, data: ItemUpdate, db: AsyncSession = Depends(get_db)
):
    item = await db.get(ListItem, item_id)
    if not item or item.list_id != list_id:
        raise HTTPException(404, "Item not found")
    if data.text is not None:
        item.text = data.text
    if data.checked is not None:
        item.checked = data.checked
        item.checked_at = _now() if data.checked else None
    if data.sort_order is not None:
        item.sort_order = data.sort_order
    await db.commit()
    await db.refresh(item)
    return _item_dict(item)


@router.delete("/{list_id}/items/checked/all", status_code=204)
async def clear_checked_items(list_id: str, db: AsyncSession = Depends(get_db)):
    q = select(ListItem).where(ListItem.list_id == list_id, ListItem.checked == 1)
    items = (await db.execute(q)).scalars().all()
    for item in items:
        await db.delete(item)
    await db.commit()


@router.delete("/{list_id}/items/{item_id}", status_code=204)
async def delete_item(list_id: str, item_id: str, db: AsyncSession = Depends(get_db)):
    item = await db.get(ListItem, item_id)
    if not item or item.list_id != list_id:
        raise HTTPException(404, "Item not found")
    await db.delete(item)
    await db.commit()


# ── Helpers ───────────────────────────────────────────────────────────────────

def _list_dict(ul: UserList) -> dict:
    return {
        "id": ul.id,
        "name": ul.name,
        "icon": ul.icon,
        "color": ul.color,
        "created_at": ul.created_at,
        "updated_at": ul.updated_at,
    }


def _item_dict(item: ListItem) -> dict:
    return {
        "id": item.id,
        "list_id": item.list_id,
        "text": item.text,
        "checked": item.checked == 1,
        "sort_order": item.sort_order,
        "created_at": item.created_at,
        "checked_at": item.checked_at,
    }
