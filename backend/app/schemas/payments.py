"""Checkout, quotes, and payment records."""
from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel


class CheckoutRequest(BaseModel):
    plan_id: str
    pet_id: str
    # "monthly" opens an installment subscription (Agreement §5.2) and charges
    # the plan's monthly price instead of the annual one. Defaults to "annual",
    # so an older app that never sends the field keeps its current behaviour.
    cadence: Literal["annual", "monthly"] = "annual"


class InstallmentRequest(BaseModel):
    """Pay the next installment on a pet's existing monthly arrangement.

    Deliberately member-initiated. This backend has no scheduler, so nothing can
    bill a saved card on a timer — and PayMongo has no card to save while only
    QR Ph is active. Paying from the app is what makes monthly work today;
    reminders are an enhancement on top, not a prerequisite.
    """
    pet_id: str


class CheckoutResponse(BaseModel):
    payment_id: str
    checkout_url: str


class PlanQuoteOut(BaseModel):
    """Member-specific price for one plan (whole pesos). discount_php > 0 only
    when the Pack Discount applies; final_php is what checkout will charge.

    eligibility mirrors plan_term_utils.purchase_eligibility for the pet_id
    passed to /payments/quotes: allowed codes 'new'/'upgrade'/'renewal',
    blocked codes 'current_plan'/'lower_plan'/'benefits_used'. The app uses it
    for display only — checkout re-validates server-side."""

    plan_id: str
    full_php: int
    discount_php: int
    final_php: int
    discount_percent: int
    eligible: bool = True
    eligibility: str = "new"
    is_current: bool = False


class PaymentOut(BaseModel):
    id: str
    plan_id: str
    amount_php: int
    discount_php: int = 0
    currency: str
    status: str
    checkout_url: Optional[str]
    created_at: datetime
    paid_at: Optional[datetime]


class AdminPaymentOut(BaseModel):
    id: str
    member_id: str
    member_first_name: str
    member_last_name: str
    member_email: Optional[str]
    pet_name: Optional[str]
    plan_name: Optional[str]
    amount_php: int
    currency: str
    status: str
    provider: str
    provider_payment_id: Optional[str]
    created_at: datetime
    paid_at: Optional[datetime]
