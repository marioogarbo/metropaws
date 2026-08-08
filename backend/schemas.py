import re
from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, List
from datetime import datetime, date
from enum import Enum

import directory_taxonomy


def validate_ph_phone(v: Optional[str]) -> Optional[str]:
    """Normalise and validate a PH mobile number.
    Accepts: 9XXXXXXXXX, 09XXXXXXXXX, +639XXXXXXXXX, 639XXXXXXXXX.
    Always stores as 10-digit local number starting with 9.
    """
    if v is None or v.strip() == "":
        return v
    digits = re.sub(r"\D", "", v)
    # Strip country code: 63 prefix (e.g. +63 or 63...)
    if digits.startswith("63") and len(digits) == 12:
        digits = digits[2:]
    # Strip leading 0 (e.g. 09...)
    elif digits.startswith("0"):
        digits = digits[1:]
    if len(digits) != 10:
        raise ValueError("Phone number must be 10 digits (e.g. 9171234567)")
    if not digits.startswith("9"):
        raise ValueError("Philippine mobile numbers must start with 9")
    return digits


class UserRole(str, Enum):
    member = "member"
    admin = "admin"
    clinic = "clinic"


# --- Auth ---
class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    last_name: str
    phone: str
    address: Optional[str] = None
    role: UserRole = UserRole.member
    plan_id: Optional[str] = None
    # Digital Agreement acceptance (members must accept the membership terms +
    # privacy policy to register). Version identifies which terms were shown.
    agreement_accepted: bool = False
    agreement_version: Optional[str] = None

    @field_validator("phone", mode="before")
    @classmethod
    def phone_must_be_ph(cls, v):
        return validate_ph_phone(v)

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: UserRole
    member_id: Optional[str] = None
    user_id: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


# --- Service Type ---
class ServiceTypeOut(BaseModel):
    id: str
    name: str
    description: Optional[str]
    icon: str

    model_config = {"from_attributes": True}


# --- Plan Selection ---
class SelectPlanRequest(BaseModel):
    plan_id: str


# --- Member Service ---
class MemberServiceOut(BaseModel):
    id: str
    service_type: ServiceTypeOut
    total_sessions: int
    used_sessions: int
    remaining_sessions: int
    expires_at: Optional[datetime]

    model_config = {"from_attributes": True}


# --- Pet Service (per-pet session record) ---
class PetServiceOut(BaseModel):
    id: str
    service_type: ServiceTypeOut
    total_sessions: int
    used_sessions: int
    remaining_sessions: int
    expires_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# --- Pet ---
class PetCreate(BaseModel):
    name: str
    sex: str
    species: str
    birth_month: int        # 1–12, required
    birth_year: int         # required
    birth_day: Optional[int] = None   # 1–31, optional
    breed: str
    weight_kg: float
    notes: Optional[str] = None


class PetUpdate(BaseModel):
    name: Optional[str] = None
    species: Optional[str] = None
    breed: Optional[str] = None
    birth_month: Optional[int] = None
    birth_year: Optional[int] = None
    birth_day: Optional[int] = None
    weight_kg: Optional[float] = None
    sex: Optional[str] = None
    notes: Optional[str] = None


class PetOut(BaseModel):
    id: str
    name: str
    species: Optional[str] = None
    breed: Optional[str]
    birth_month: Optional[int]
    birth_year: Optional[int]
    birth_day: Optional[int]
    weight_kg: Optional[float]
    sex: Optional[str]
    photo_url: Optional[str]
    vax_card_url: Optional[str]
    notes: Optional[str]
    plan_id: Optional[str] = None
    plan_type: Optional[str] = None
    plan_activated_at: Optional[datetime] = None
    created_at: datetime
    pet_services: List[PetServiceOut] = []

    # Identity photos (MP-FRM-PET-001) — photo_url above is slot 1 (front face).
    photo_full_body_url: Optional[str] = None
    photo_with_owner_url: Optional[str] = None
    photo_left_profile_url: Optional[str] = None
    photo_right_profile_url: Optional[str] = None
    photo_rear_url: Optional[str] = None
    photo_top_url: Optional[str] = None
    photo_with_id_card_url: Optional[str] = None
    is_profile_verified: bool = False

    model_config = {"from_attributes": True}


class PetActivatePlanRequest(BaseModel):
    plan_id: str


# --- Member ---
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
    joined_at: datetime
    pets: List[PetOut] = []
    services: List[MemberServiceOut] = []

    model_config = {"from_attributes": True}


class MemberSummary(BaseModel):
    id: str
    email: Optional[str] = None
    first_name: str
    last_name: str
    plan_type: Optional[str] = None
    qr_token: str
    is_founding: bool = False
    joined_at: datetime
    pets: List[PetOut] = []
    services: List[MemberServiceOut] = []

    model_config = {"from_attributes": True}


# --- Service Log ---
class DeployServiceRequest(BaseModel):
    member_id: str
    service_type_id: str
    pet_id: Optional[str] = None
    notes: Optional[str] = None


class ServiceLogOut(BaseModel):
    id: str
    service_type: ServiceTypeOut
    notes: Optional[str]
    logged_at: datetime

    model_config = {"from_attributes": True}


# --- Admin: Member Services Setup ---
class AssignServiceRequest(BaseModel):
    member_id: str
    service_type_id: str
    total_sessions: int
    expires_at: Optional[datetime] = None


# --- Plan Services ---
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


# --- Plans ---
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


# --- Clinic Partner ---
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


# --- Reimbursement Provider (verified direct-pay payee; unrelated to ClinicPartner/booking) ---
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


# --- Clinic scan ---
class ServiceLogBriefOut(BaseModel):
    id: str
    service_type: ServiceTypeOut
    notes: Optional[str]
    logged_at: datetime

    model_config = {"from_attributes": True}


class PetWithHistoryOut(BaseModel):
    id: str
    name: str
    species: Optional[str] = None
    breed: Optional[str] = None
    birth_month: Optional[int] = None
    birth_year: Optional[int] = None
    birth_day: Optional[int] = None
    weight_kg: Optional[float] = None
    sex: Optional[str] = None
    photo_url: Optional[str] = None
    vax_card_url: Optional[str] = None
    notes: Optional[str] = None
    pet_services: List[PetServiceOut] = []
    service_logs: List[ServiceLogBriefOut] = []

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


# --- Clinic Brief (for booking responses) ---
class ClinicBriefOut(BaseModel):
    id: str
    clinic_name: str
    address: Optional[str]
    phone: Optional[str]

    model_config = {"from_attributes": True}


# --- Bookings ---
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


class MemberBriefOut(BaseModel):
    id: str
    first_name: str
    last_name: str
    plan_type: Optional[str] = None

    model_config = {"from_attributes": True}


# --- Payments ---
class CheckoutRequest(BaseModel):
    plan_id: str
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


# --- App Settings ---
class AppSettingOut(BaseModel):
    key: str
    value: str

    model_config = {"from_attributes": True}


class PaymentsEnabledOut(BaseModel):
    payments_enabled: bool


class PaymentsEnabledUpdate(BaseModel):
    payments_enabled: bool

    model_config = {"from_attributes": True}


# --- Founding 50 ---
class Founding50Out(BaseModel):
    enabled: bool
    limit: int
    claimed: int


class Founding50Update(BaseModel):
    enabled: bool
    limit: int = 50


class FoundingStatusUpdate(BaseModel):
    is_founding: bool


# --- Admin: Member Create ---
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


# --- FAQs ---
class FAQCreate(BaseModel):
    question: str
    answer: str
    sort_order: int = 0
    is_published: bool = True


class FAQUpdate(BaseModel):
    question: Optional[str] = None
    answer: Optional[str] = None
    sort_order: Optional[int] = None
    is_published: Optional[bool] = None


class FAQOut(BaseModel):
    id: str
    question: str
    answer: str
    sort_order: int
    is_published: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class FAQReorderRequest(BaseModel):
    ids: List[str]


# --- Events & Promos ---
class PromoCreate(BaseModel):
    title: str
    body: Optional[str] = None
    type: str = "promo"  # 'event' | 'promo'
    event_date: Optional[datetime] = None
    location: Optional[str] = None
    link_url: Optional[str] = None
    image_url: Optional[str] = None
    is_published: bool = True
    sort_order: int = 0

    @field_validator("type")
    @classmethod
    def type_must_be_known(cls, v):
        if v not in ("event", "promo"):
            raise ValueError("type must be 'event' or 'promo'")
        return v


class PromoUpdate(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None
    type: Optional[str] = None
    event_date: Optional[datetime] = None
    location: Optional[str] = None
    link_url: Optional[str] = None
    image_url: Optional[str] = None
    is_published: Optional[bool] = None
    sort_order: Optional[int] = None

    @field_validator("type")
    @classmethod
    def type_must_be_known(cls, v):
        if v is not None and v not in ("event", "promo"):
            raise ValueError("type must be 'event' or 'promo'")
        return v


class PromoOut(BaseModel):
    id: str
    title: str
    body: Optional[str] = None
    type: str
    event_date: Optional[datetime] = None
    location: Optional[str] = None
    link_url: Optional[str] = None
    image_url: Optional[str] = None
    is_published: bool
    sort_order: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# --- Pet Care Directory (public community listings) ---

def _clean_services(v):
    """Drop blanks, then reject anything outside the shared vocabulary.

    Runs `mode="before"` so a form that posts an empty checkbox value doesn't
    trip the validator with a "" slug the operator never chose.
    """
    if v is None:
        return v
    cleaned = [s.strip() for s in v if isinstance(s, str) and s.strip()]
    return directory_taxonomy.validate_services(cleaned)


def _strip_name(v):
    return v.strip() if isinstance(v, str) else v


class DirectoryProviderCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    services: List[str] = []
    address: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    website: Optional[str] = None
    hours: Optional[str] = None
    map_url: Optional[str] = None
    is_partner: bool = False
    is_published: bool = True

    @field_validator("services", mode="before")
    @classmethod
    def services_must_be_known(cls, v):
        return _clean_services(v)

    @field_validator("name", mode="before")
    @classmethod
    def name_is_trimmed(cls, v):
        return _strip_name(v)


class DirectoryProviderUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    services: Optional[List[str]] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    website: Optional[str] = None
    hours: Optional[str] = None
    map_url: Optional[str] = None
    is_partner: Optional[bool] = None
    is_published: Optional[bool] = None

    @field_validator("services", mode="before")
    @classmethod
    def services_must_be_known(cls, v):
        return _clean_services(v)

    @field_validator("name", mode="before")
    @classmethod
    def name_is_trimmed(cls, v):
        return _strip_name(v)


class DirectoryProviderOut(BaseModel):
    id: str
    name: str
    services: List[str]
    address: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    website: Optional[str] = None
    hours: Optional[str] = None
    map_url: Optional[str] = None
    is_partner: bool
    is_published: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# --- Mobile app config (feature flags the app reads at startup) ---
class MobileConfigOut(BaseModel):
    booking_enabled: bool
    direct_provider_payment_enabled: bool = False


class BookingEnabledUpdate(BaseModel):
    booking_enabled: bool


class DirectProviderPaymentUpdate(BaseModel):
    direct_provider_payment_enabled: bool


class PackDiscountOut(BaseModel):
    enabled: bool
    percent: int


class PackDiscountUpdate(BaseModel):
    enabled: bool
    percent: int = Field(ge=0, le=100)


# --- Founding 50 Reservations ---

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


# --- PawPoints ---
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


# --- Reimbursements ---
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


class WalletOut(BaseModel):
    pets: List[WalletPetOut] = []
    service_types: List[ServiceTypeOut] = []


class NotificationOut(BaseModel):
    id: str
    title: str
    body: Optional[str] = None
    type: str
    reference_id: Optional[str] = None
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}

