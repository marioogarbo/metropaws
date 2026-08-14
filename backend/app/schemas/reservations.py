"""Founding 50 reservations."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel



class FoundingReservationCreate(BaseModel):
    first_name: str
    last_name: str
    email: str
    phone: Optional[str] = None
    barangay: str
    message: Optional[str] = None


class FoundingReservationStatusUpdate(BaseModel):
    status: str  # pending | approved | rejected
    admin_notes: Optional[str] = None


class FoundingReservationOut(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: str
    phone: Optional[str] = None
    barangay: str
    message: Optional[str] = None
    status: str
    admin_notes: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
