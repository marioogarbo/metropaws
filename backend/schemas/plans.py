"""Membership plans and their per-category session / cap rows."""
from typing import List, Optional

from pydantic import BaseModel, Field

from schemas.services import ServiceTypeOut


class SelectPlanRequest(BaseModel):
    plan_id: str


class PlanServiceOut(BaseModel):
    id: str
    service_type: ServiceTypeOut
    sessions: int
    # Annual reimbursement ceiling for this category (centavos). 0 = not reimbursable.
    reimbursement_cap_centavos: int = 0

    model_config = {"from_attributes": True}


class PlanServiceCapUpdate(BaseModel):
    """One plan × category reimbursement edit (centavos). When the category is not
    yet on the plan, a new plan_services row is created. `sessions` is only used
    when creating (or explicitly changing) the row's session grant; it applies to
    new activations/renewals, not to pets already on the plan."""
    service_type_id: str
    reimbursement_cap_centavos: int = Field(ge=0, le=100_000_000)  # ₱0 – ₱1,000,000
    sessions: Optional[int] = Field(default=None, ge=0, le=365)


class PlanCreate(BaseModel):
    name: str
    price: int
    price_monthly: Optional[int] = None
    tagline: Optional[str] = None
    features: List[str] = []
    is_featured: bool = False
    is_active: bool = True
    sort_order: int = 0
    # Annual Preventive Wellness Wallet (centavos) — non-emergency claims draw here.
    reimbursement_wallet_centavos: int = Field(default=0, ge=0, le=100_000_000)
    # Annual Emergency Wallet (centavos) — "Emergency"-category claims draw here.
    emergency_wallet_centavos: int = Field(default=0, ge=0, le=100_000_000)


class PlanUpdate(BaseModel):
    name: Optional[str] = None
    price: Optional[int] = None
    price_monthly: Optional[int] = None
    tagline: Optional[str] = None
    features: Optional[List[str]] = None
    is_featured: Optional[bool] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None
    # Annual Preventive Wellness Wallet (centavos) — non-emergency claims draw here.
    reimbursement_wallet_centavos: Optional[int] = Field(default=None, ge=0, le=100_000_000)
    # Annual Emergency Wallet (centavos) — "Emergency"-category claims draw here.
    emergency_wallet_centavos: Optional[int] = Field(default=None, ge=0, le=100_000_000)
    # Legacy per-category cap edits (kept for API compat; caps no longer gate claims).
    service_caps: Optional[List[PlanServiceCapUpdate]] = None


class PlanOut(BaseModel):
    id: str
    name: str
    price: int
    price_monthly: Optional[int] = None
    tagline: Optional[str]
    features: List[str]
    is_featured: bool
    is_active: bool
    sort_order: int
    reimbursement_wallet_centavos: int = 0
    emergency_wallet_centavos: int = 0
    plan_services: List[PlanServiceOut] = []

    model_config = {"from_attributes": True}
