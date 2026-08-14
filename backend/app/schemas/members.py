"""Member profiles, admin-side member creation, and the brief shape other modules embed."""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, EmailStr, field_validator

from app.schemas.pets import PetOut
from app.schemas.services import MemberServiceOut
from app.schemas.validators import validate_ph_phone


class MemberUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    plan_type: Optional[str] = None
    payout_method: Optional[str] = None
    payout_account_name: Optional[str] = None
    payout_account_number: Optional[str] = None
    payout_bank_name: Optional[str] = None

    @field_validator("phone", mode="before")
    @classmethod
    def phone_must_be_ph(cls, v):
        return validate_ph_phone(v)


class MemberOut(BaseModel):
    id: str
    user_id: str
    first_name: str
    last_name: str
    phone: Optional[str]
    address: Optional[str]
    photo_url: Optional[str] = None
    plan_type: Optional[str] = None
    payout_method: Optional[str] = None
    payout_account_name: Optional[str] = None
    payout_account_number: Optional[str] = None
    payout_bank_name: Optional[str] = None
    qr_token: str
    is_founding: bool = False
    previous_plan_tier: Optional[str] = None
    # None = follows the global direct-pay switch; True/False = admin override.
    direct_pay_enabled: Optional[bool] = None
    direct_pay_note: Optional[str] = None
    direct_pay_updated_at: Optional[datetime] = None
    joined_at: datetime
    pets: List[PetOut] = []
    services: List[MemberServiceOut] = []

    model_config = {"from_attributes": True}


class MemberDirectPayUpdate(BaseModel):
    """Admin override of a member's direct-to-provider eligibility.

    `direct_pay_enabled` is deliberately tri-state: None restores "follow the
    global switch" rather than pinning the member to today's global value.
    """
    direct_pay_enabled: Optional[bool] = None
    direct_pay_note: Optional[str] = None


class MemberSummary(BaseModel):
    id: str
    email: Optional[str] = None
    first_name: str
    last_name: str
    plan_type: Optional[str] = None
    qr_token: str
    is_founding: bool = False
    # Carried on the summary because the admin member detail page reads the
    # members LIST rather than a per-member endpoint.
    direct_pay_enabled: Optional[bool] = None
    direct_pay_note: Optional[str] = None
    direct_pay_updated_at: Optional[datetime] = None
    joined_at: datetime
    pets: List[PetOut] = []
    services: List[MemberServiceOut] = []

    model_config = {"from_attributes": True}


class MemberBriefOut(BaseModel):
    id: str
    first_name: str
    last_name: str
    plan_type: Optional[str] = None

    model_config = {"from_attributes": True}


class AdminMemberCreate(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    last_name: str
    phone: Optional[str] = None
    address: Optional[str] = None

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v

    @field_validator("phone", mode="before")
    @classmethod
    def phone_must_be_ph(cls, v):
        return validate_ph_phone(v)
