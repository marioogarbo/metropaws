"""Appointment bookings in their member, admin and clinic shapes.

ClinicBriefOut lives here rather than with the clinic partner schemas because
it exists for booking responses, and keeping it here is what stops clinics and
bookings importing each other.
"""
from datetime import date, datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel

from schemas.members import MemberBriefOut
from schemas.services import ServiceTypeOut


class ClinicBriefOut(BaseModel):
    id: str
    clinic_name: str
    address: Optional[str]
    phone: Optional[str]

    model_config = {"from_attributes": True}


class BookingStatus(str, Enum):
    pending = "pending"
    confirmed = "confirmed"
    cancelled = "cancelled"


class BookingCreate(BaseModel):
    service_type_id: str
    clinic_id: str
    booking_date: date
    time_slot: str
    notes: Optional[str] = None


class BookingOut(BaseModel):
    id: str
    service_type: ServiceTypeOut
    clinic: Optional[ClinicBriefOut]
    booking_date: date
    time_slot: str
    status: BookingStatus
    credit_used: bool = False
    notes: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class AdminBookingOut(BaseModel):
    id: str
    member: MemberBriefOut
    service_type: ServiceTypeOut
    clinic: Optional[ClinicBriefOut]
    booking_date: date
    time_slot: str
    status: BookingStatus
    credit_used: bool = False
    notes: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class ClinicBookingOut(BaseModel):
    id: str
    member: MemberBriefOut
    service_type: ServiceTypeOut
    booking_date: date
    time_slot: str
    status: BookingStatus
    notes: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}
