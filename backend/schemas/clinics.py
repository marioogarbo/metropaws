"""Partner clinics and the result of a clinic-side QR scan."""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, EmailStr, field_validator

from schemas.bookings import ClinicBookingOut
from schemas.pets import PetWithHistoryOut
from schemas.services import MemberServiceOut


class ClinicPartnerCreate(BaseModel):
    email: EmailStr
    password: str
    clinic_name: str
    phone: Optional[str] = None
    address: Optional[str] = None

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class ClinicPartnerUpdate(BaseModel):
    clinic_name: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None


class ClinicPartnerOut(BaseModel):
    id: str
    clinic_name: str
    phone: Optional[str]
    address: Optional[str]
    user_id: str
    email: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class ClinicScanResult(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    plan_type: Optional[str] = None
    services: List[MemberServiceOut] = []
    pets: List[PetWithHistoryOut] = []
    bookings: List["ClinicBookingOut"] = []

    model_config = {"from_attributes": True}
