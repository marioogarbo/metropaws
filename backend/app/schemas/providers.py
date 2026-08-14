"""Reimbursement providers — verified direct-pay payees."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel



class ReimbursementProviderCreate(BaseModel):
    name: str
    category: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    payout_method: Optional[str] = None
    payout_account_name: Optional[str] = None
    payout_account_number: Optional[str] = None
    payout_bank_name: Optional[str] = None
    is_active: bool = True


class ReimbursementProviderUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    payout_method: Optional[str] = None
    payout_account_name: Optional[str] = None
    payout_account_number: Optional[str] = None
    payout_bank_name: Optional[str] = None
    is_active: Optional[bool] = None


class ReimbursementProviderOut(BaseModel):
    id: str
    name: str
    category: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    payout_method: Optional[str] = None
    payout_account_name: Optional[str] = None
    payout_account_number: Optional[str] = None
    payout_bank_name: Optional[str] = None
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class ReimbursementProviderBriefOut(BaseModel):
    """Member-facing shape for the provider picker — never exposes payout details."""
    id: str
    name: str
    category: Optional[str] = None

    model_config = {"from_attributes": True}
