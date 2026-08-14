"""Editorial content the admin manages: FAQs, events and promos."""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, field_validator


class FAQCreate(BaseModel):
    question: str
    answer: str
    sort_order: int = 0
    is_published: bool = True


class FAQUpdate(BaseModel):
    question: Optional[str] = None
    answer: Optional[str] = None
    sort_order: Optional[int] = None
    is_published: Optional[bool] = None


class FAQOut(BaseModel):
    id: str
    question: str
    answer: str
    sort_order: int
    is_published: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class FAQReorderRequest(BaseModel):
    ids: List[str]


class PromoCreate(BaseModel):
    title: str
    body: Optional[str] = None
    type: str = "promo"  # 'event' | 'promo'
    event_date: Optional[datetime] = None
    location: Optional[str] = None
    link_url: Optional[str] = None
    image_url: Optional[str] = None
    is_published: bool = True
    sort_order: int = 0

    @field_validator("type")
    @classmethod
    def type_must_be_known(cls, v):
        if v not in ("event", "promo"):
            raise ValueError("type must be 'event' or 'promo'")
        return v


class PromoUpdate(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None
    type: Optional[str] = None
    event_date: Optional[datetime] = None
    location: Optional[str] = None
    link_url: Optional[str] = None
    image_url: Optional[str] = None
    is_published: Optional[bool] = None
    sort_order: Optional[int] = None

    @field_validator("type")
    @classmethod
    def type_must_be_known(cls, v):
        if v is not None and v not in ("event", "promo"):
            raise ValueError("type must be 'event' or 'promo'")
        return v


class PromoOut(BaseModel):
    id: str
    title: str
    body: Optional[str] = None
    type: str
    event_date: Optional[datetime] = None
    location: Optional[str] = None
    link_url: Optional[str] = None
    image_url: Optional[str] = None
    is_published: bool
    sort_order: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}
