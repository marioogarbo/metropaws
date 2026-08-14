"""Paw Points balances, ledger entries, and rewards."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class PawPointsBalanceOut(BaseModel):
    current_balance: int
    lifetime_earned: int


class PawPointsTransactionOut(BaseModel):
    id: str
    points: int
    activity_type: str
    reference_id: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class PawRewardOut(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    points_required: int
    reward_type: str
    is_active: bool
    sort_order: int

    model_config = {"from_attributes": True}


class PawAwardRequest(BaseModel):
    member_id: str
    points: int
    notes: Optional[str] = None
