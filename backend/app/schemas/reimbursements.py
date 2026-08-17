"""Reimbursement claims, their audit events, and the Benefit Wallet.

Money is always integer centavos here; it is formatted to pesos at the UI edge.
"""
from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel

from app.schemas.providers import ReimbursementProviderOut
from app.schemas.services import ServiceTypeOut


# Money is always integer centavos (₱523.75 -> 52375). Format to ₱ at the UI edge.

class ReimbursementEventOut(BaseModel):
    id: str
    from_status: Optional[str] = None
    to_status: str
    note: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ReimbursementOut(BaseModel):
    id: str
    pet_id: str
    service_type: ServiceTypeOut
    provider_name: str
    service_date: date
    claimed_amount_centavos: int
    approved_amount_centavos: Optional[int] = None
    receipt_url: str
    receipt_reference: Optional[str] = None
    member_notes: Optional[str] = None
    status: str
    admin_notes: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    paid_at: Optional[datetime] = None
    paid_reference: Optional[str] = None
    payout_target: str = "member"
    provider_id: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ReimbursementPetOut(BaseModel):
    id: str
    name: str
    species: Optional[str] = None
    photo_url: Optional[str] = None
    plan_type: Optional[str] = None

    model_config = {"from_attributes": True}


class ReimbursementMemberOut(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: Optional[str] = None
    plan_type: Optional[str] = None
    payout_method: Optional[str] = None
    payout_account_name: Optional[str] = None
    payout_account_number: Optional[str] = None
    payout_bank_name: Optional[str] = None

    model_config = {"from_attributes": True}


class AdminReimbursementOut(ReimbursementOut):
    member: ReimbursementMemberOut
    pet: ReimbursementPetOut
    provider: Optional[ReimbursementProviderOut] = None
    events: List[ReimbursementEventOut] = []


class ReimbursementReviewRequest(BaseModel):
    status: str  # under_review | needs_info | approved | rejected
    approved_amount_centavos: Optional[int] = None
    admin_notes: Optional[str] = None


class MarkPaidRequest(BaseModel):
    payment_reference: str  # GCash/bank transaction ref — required for reconciliation
    admin_notes: Optional[str] = None


class WalletPetOut(BaseModel):
    pet_id: str
    pet_name: str
    # Preventive Wellness Wallet — non-emergency claims draw from this pool.
    wallet_centavos: int          # the plan's annual preventive pool
    pending_centavos: int         # sum of claimed amounts awaiting decision
    used_centavos: int            # sum of approved + paid amounts
    remaining_centavos: int       # max(0, wallet - used - pending)
    # Emergency Wallet — "Emergency"-category claims draw from this separate pool.
    emergency_wallet_centavos: int = 0
    emergency_pending_centavos: int = 0
    emergency_used_centavos: int = 0
    emergency_remaining_centavos: int = 0
    # Plan term (plan_term_utils): 'active' | 'renewal_window' | 'expired';
    # expired pets can't file new claims until renewed. plan_expires_at is None
    # for legacy plans with no activation date (they never expire).
    plan_status: str = "active"
    plan_expires_at: Optional[datetime] = None
    # Agreement §5.7 status. `membership_status` is the stable wire value;
    # `membership_status_label` is the contract's exact wording, served so the
    # app shows it without hardcoding a phrase that only the document may change.
    membership_status: str = "fully_service_eligible"
    membership_status_label: str = "Fully Service-Eligible"
    # Monthly subscribers only — all None/0 for an annual member, which is how
    # the app tells the two apart. next_due_on is what a "pay next instalment"
    # action keys off, since nothing here bills automatically.
    subscription_next_due_on: Optional[date] = None
    subscription_payments_made: int = 0


class WalletOut(BaseModel):
    pets: List[WalletPetOut] = []
    service_types: List[ServiceTypeOut] = []
    # Whether THIS member may file a direct-to-provider request — the global
    # setting resolved against their per-member override. /settings/mobile-config
    # is unauthenticated and can only carry the global switch, so this is the
    # value the app gates the option on.
    direct_pay_available: bool = False
