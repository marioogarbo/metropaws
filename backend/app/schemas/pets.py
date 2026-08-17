"""Pets, including the history view used by the clinic scan."""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel

from app.schemas.services import PetServiceOut, ServiceLogBriefOut


class PetCreate(BaseModel):
    name: str
    sex: str
    species: str
    birth_month: int        # 1–12, required
    birth_year: int         # required
    birth_day: Optional[int] = None   # 1–31, optional
    breed: str
    weight_kg: float
    notes: Optional[str] = None


class PetUpdate(BaseModel):
    name: Optional[str] = None
    species: Optional[str] = None
    breed: Optional[str] = None
    birth_month: Optional[int] = None
    birth_year: Optional[int] = None
    birth_day: Optional[int] = None
    weight_kg: Optional[float] = None
    sex: Optional[str] = None
    notes: Optional[str] = None


class PetOut(BaseModel):
    id: str
    name: str
    species: Optional[str] = None
    breed: Optional[str]
    birth_month: Optional[int]
    birth_year: Optional[int]
    birth_day: Optional[int]
    weight_kg: Optional[float]
    sex: Optional[str]
    photo_url: Optional[str]
    vax_card_url: Optional[str]
    notes: Optional[str]
    plan_id: Optional[str] = None
    plan_type: Optional[str] = None
    plan_activated_at: Optional[datetime] = None
    # 'annual' | 'monthly' — HOW the plan is paid, which the plan list needs
    # so it does not claim a monthly subscriber holds an annual plan.
    plan_cadence: str = "annual"
    created_at: datetime
    pet_services: List[PetServiceOut] = []

    # Identity photos (MP-FRM-PET-001) — photo_url above is slot 1 (front face).
    photo_full_body_url: Optional[str] = None
    photo_with_owner_url: Optional[str] = None
    photo_left_profile_url: Optional[str] = None
    photo_right_profile_url: Optional[str] = None
    photo_rear_url: Optional[str] = None
    photo_top_url: Optional[str] = None
    photo_with_id_card_url: Optional[str] = None
    is_profile_verified: bool = False

    model_config = {"from_attributes": True}


class PetActivatePlanRequest(BaseModel):
    plan_id: str


class PetWithHistoryOut(BaseModel):
    id: str
    name: str
    species: Optional[str] = None
    breed: Optional[str] = None
    birth_month: Optional[int] = None
    birth_year: Optional[int] = None
    birth_day: Optional[int] = None
    weight_kg: Optional[float] = None
    sex: Optional[str] = None
    photo_url: Optional[str] = None
    vax_card_url: Optional[str] = None
    notes: Optional[str] = None
    pet_services: List[PetServiceOut] = []
    service_logs: List[ServiceLogBriefOut] = []

    model_config = {"from_attributes": True}
