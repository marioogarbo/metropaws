"""Paw Points balances, ledger entries, and rewards."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


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


class PawRewardCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    description: Optional[str] = None
    points_required: int = Field(gt=0)
    reward_type: str = "merchandise"
    is_active: bool = True
    sort_order: int = 0


class PawRewardUpdate(BaseModel):
    """Every field optional — a PATCH sends only what changed. Deactivating is
    an update (``is_active=false``), not a delete, so a reward that members have
    already been shown can be retired without vanishing from the catalogue."""
    name: Optional[str] = Field(default=None, min_length=1, max_length=200)
    description: Optional[str] = None
    points_required: Optional[int] = Field(default=None, gt=0)
    reward_type: Optional[str] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


class PawPointsMemberBalanceOut(BaseModel):
    """One row of the admin's per-member PawPoints table."""
    member_id: str
    first_name: str
    last_name: str
    email: Optional[str] = None
    plan_type: Optional[str] = None
    current_balance: int
    lifetime_earned: int
    last_activity_at: Optional[datetime] = None


class PawPointsMemberDetailOut(BaseModel):
    balance: PawPointsBalanceOut
    history: list[PawPointsTransactionOut]


class PawRewardReachOut(BaseModel):
    """How many members could claim a given reward right now.

    This is the honest form of the "liability estimate" the framework asks for:
    the catalogue carries no cost-per-reward, so a peso figure would be invented.
    A count of members already over each threshold is derived from real balances
    and is what actually drives exposure.
    """
    reward_id: str
    name: str
    points_required: int
    members_eligible: int


class PawPointsTopEarnerOut(BaseModel):
    member_id: str
    first_name: str
    last_name: str
    lifetime_earned: int
    current_balance: int


class PawPointsAdminSummaryOut(BaseModel):
    total_issued: int
    total_redeemed: int
    total_outstanding: int
    members_with_points: int
    top_earners: list[PawPointsTopEarnerOut]
    reward_reach: list[PawRewardReachOut]
