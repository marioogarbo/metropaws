from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, Date, ForeignKey, Text, Enum, JSON, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
import enum
import uuid


def gen_uuid():
    return str(uuid.uuid4())


class UserRole(str, enum.Enum):
    member = "member"
    admin = "admin"
    clinic = "clinic"


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=gen_uuid)
    email = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    role = Column(Enum(UserRole), default=UserRole.member, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # foreign_keys is explicit because members now has a SECOND FK to users
    # (direct_pay_updated_by_admin_id) — without it SQLAlchemy can't tell which
    # column joins this pair and fails at mapper configuration, i.e. on import.
    member = relationship(
        "Member",
        back_populates="user",
        uselist=False,
        foreign_keys="Member.user_id",
    )
    clinic_partner = relationship("ClinicPartner", back_populates="user", uselist=False)


class Member(Base):
    __tablename__ = "members"

    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, ForeignKey("users.id"), unique=True, nullable=False)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    phone = Column(String)
    address = Column(Text)
    photo_url = Column(String, nullable=True)
    # Where approved reimbursements are sent (payout is settled offline; these
    # tell the admin where to send it). Method e.g. 'gcash' | 'bank'.
    payout_method = Column(String, nullable=True)
    payout_account_name = Column(String, nullable=True)
    payout_account_number = Column(String, nullable=True)
    payout_bank_name = Column(String, nullable=True)  # only for bank transfers
    plan_type = Column(String, nullable=True)
    plan_id = Column(String, ForeignKey("plans.id"), nullable=True)
    qr_token = Column(String, unique=True, default=gen_uuid, index=True)
    is_founding = Column(Boolean, default=False, nullable=False)
    previous_plan_tier = Column(String, nullable=True)
    # Membership-agreement acceptance captured at registration (Digital
    # Agreement step). Null for legacy members created before this was added.
    agreement_accepted_at = Column(DateTime(timezone=True), nullable=True)
    agreement_version = Column(String, nullable=True)
    # Per-member override of the global direct_provider_payment_enabled setting.
    # NULL = follow the global switch (the default for everyone), True = allowed
    # even while the global switch is off (pilot), False = restricted regardless.
    # This is the "Authorization Restricted" member status of Agreement §5.7, and
    # §17 supplies the grounds — so the reason is recorded, not just the flag.
    direct_pay_enabled = Column(Boolean, nullable=True)
    direct_pay_note = Column(Text, nullable=True)
    direct_pay_updated_by_admin_id = Column(String, ForeignKey("users.id"), nullable=True)
    direct_pay_updated_at = Column(DateTime(timezone=True), nullable=True)
    joined_at = Column(DateTime(timezone=True), server_default=func.now())

    # Explicit foreign_keys on both User-facing relationships — see User.member.
    user = relationship("User", back_populates="member", foreign_keys=[user_id])
    direct_pay_updated_by = relationship(
        "User", foreign_keys=[direct_pay_updated_by_admin_id]
    )
    plan = relationship("Plan")
    pets = relationship("Pet", back_populates="member", cascade="all, delete-orphan")
    services = relationship("MemberService", back_populates="member", cascade="all, delete-orphan")
    service_logs = relationship("ServiceLog", back_populates="member")
    bookings = relationship("Booking", back_populates="member", cascade="all, delete-orphan")

    @property
    def email(self) -> str | None:
        return self.user.email if self.user else None


class Pet(Base):
    __tablename__ = "pets"

    id = Column(String, primary_key=True, default=gen_uuid)
    member_id = Column(String, ForeignKey("members.id"), nullable=False)
    name = Column(String, nullable=False)
    species = Column(String)
    breed = Column(String, nullable=False)
    birth_month = Column(Integer, nullable=False)  # 1–12
    birth_year = Column(Integer, nullable=False)
    birth_day = Column(Integer, nullable=True)     # 1–31, optional
    weight_kg = Column(Float, nullable=False)
    photo_url = Column(String)  # slot 1: front face — required at registration
    vax_card_url = Column(String)
    sex = Column(String)  # 'male', 'female'
    notes = Column(Text)
    plan_id = Column(String, ForeignKey("plans.id"), nullable=True)
    plan_type = Column(String, nullable=True)
    plan_activated_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Additional identity photos (MP-FRM-PET-001). Front face (photo_url) plus
    # full body and pet+owner are required at registration; the remaining four
    # angles are optional and can be added later from the pet's profile. A
    # profile is "verified" once all 8 are present — see is_profile_verified.
    photo_full_body_url = Column(String, nullable=True)      # slot 2: required at registration
    photo_with_owner_url = Column(String, nullable=True)     # slot 3: required at registration
    photo_left_profile_url = Column(String, nullable=True)   # slot 4: optional, add later
    photo_right_profile_url = Column(String, nullable=True)  # slot 5: optional, add later
    photo_rear_url = Column(String, nullable=True)           # slot 6: optional, add later
    photo_top_url = Column(String, nullable=True)             # slot 7: optional, add later
    # Requires the pet's QR to already exist, so this is always filled in
    # after registration rather than at creation time.
    photo_with_id_card_url = Column(String, nullable=True)   # slot 8: optional, add later

    member = relationship("Member", back_populates="pets")
    plan = relationship("Plan")
    service_logs = relationship("ServiceLog", back_populates="pet")
    pet_services = relationship("PetService", back_populates="pet", cascade="all, delete-orphan")

    @property
    def is_profile_verified(self) -> bool:
        return all([
            self.photo_url,
            self.photo_full_body_url,
            self.photo_with_owner_url,
            self.photo_left_profile_url,
            self.photo_right_profile_url,
            self.photo_rear_url,
            self.photo_top_url,
            self.photo_with_id_card_url,
        ])


class ServiceType(Base):
    __tablename__ = "service_types"

    id = Column(String, primary_key=True, default=gen_uuid)
    name = Column(String, unique=True, nullable=False)
    description = Column(Text)
    icon = Column(String, default="pets")

    member_services = relationship("MemberService", back_populates="service_type")
    service_logs = relationship("ServiceLog", back_populates="service_type")
    pet_services = relationship("PetService", back_populates="service_type")


class MemberService(Base):
    __tablename__ = "member_services"

    id = Column(String, primary_key=True, default=gen_uuid)
    member_id = Column(String, ForeignKey("members.id"), nullable=False)
    service_type_id = Column(String, ForeignKey("service_types.id"), nullable=False)
    total_sessions = Column(Integer, default=0)
    used_sessions = Column(Integer, default=0)
    expires_at = Column(DateTime(timezone=True), nullable=True)

    member = relationship("Member", back_populates="services")
    service_type = relationship("ServiceType", back_populates="member_services")

    @property
    def remaining_sessions(self):
        return max(0, self.total_sessions - self.used_sessions)


class ServiceLog(Base):
    __tablename__ = "service_logs"

    id = Column(String, primary_key=True, default=gen_uuid)
    member_id = Column(String, ForeignKey("members.id"), nullable=False)
    pet_id = Column(String, ForeignKey("pets.id"), nullable=True)
    service_type_id = Column(String, ForeignKey("service_types.id"), nullable=False)
    logged_by_admin_id = Column(String, ForeignKey("users.id"), nullable=False)
    notes = Column(Text)
    logged_at = Column(DateTime(timezone=True), server_default=func.now())

    member = relationship("Member", back_populates="service_logs")
    pet = relationship("Pet", back_populates="service_logs")
    service_type = relationship("ServiceType", back_populates="service_logs")
    admin = relationship("User", foreign_keys=[logged_by_admin_id])


class PetService(Base):
    __tablename__ = "pet_services"
    __table_args__ = (
        # Enforce one row per (pet, service_type) — prevents duplicate rows
        # from concurrent plan assignments or the founding-bonus flush-ordering bug.
        UniqueConstraint("pet_id", "service_type_id", name="uq_pet_service"),
    )

    id = Column(String, primary_key=True, default=gen_uuid)
    pet_id = Column(String, ForeignKey("pets.id"), nullable=False)
    service_type_id = Column(String, ForeignKey("service_types.id"), nullable=False)
    total_sessions = Column(Integer, default=0)
    used_sessions = Column(Integer, default=0)
    expires_at = Column(DateTime(timezone=True), nullable=True)

    pet = relationship("Pet", back_populates="pet_services")
    service_type = relationship("ServiceType", back_populates="pet_services")

    @property
    def remaining_sessions(self):
        return max(0, self.total_sessions - self.used_sessions)


class BookingStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    cancelled = "cancelled"


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(String, primary_key=True, default=gen_uuid)
    member_id = Column(String, ForeignKey("members.id"), nullable=False)
    service_type_id = Column(String, ForeignKey("service_types.id"), nullable=False)
    booking_date = Column(Date, nullable=False)
    time_slot = Column(String, nullable=False)
    clinic_id = Column(String, ForeignKey("clinic_partners.id"), nullable=True)
    status = Column(Enum(BookingStatus), default=BookingStatus.pending, nullable=False)
    credit_used = Column(Boolean, default=False, nullable=False)
    notes = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    member = relationship("Member", back_populates="bookings")
    service_type = relationship("ServiceType")
    clinic = relationship("ClinicPartner")


class Plan(Base):
    __tablename__ = "plans"

    id = Column(String, primary_key=True, default=gen_uuid)
    name = Column(String, nullable=False)
    price = Column(Integer, nullable=False)        # annual price in PHP
    price_monthly = Column(Integer, nullable=True) # monthly price in PHP
    tagline = Column(String, nullable=True)
    features = Column(JSON, nullable=False, default=list)  # list of feature strings
    is_featured = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    sort_order = Column(Integer, default=0)
    # Two annual reimbursement pools per plan (centavos). A claim's service
    # category decides which pool it draws from: the "Emergency" category draws
    # from emergency_wallet_centavos, everything else from the Preventive Wellness
    # pool below (client decision 2026-07-16, reversing the single-pool model that
    # was designed but never deployed). 0 = plan has no wallet of that kind. The
    # per-category PlanService.reimbursement_cap_centavos is legacy and no longer
    # consulted for gating.
    reimbursement_wallet_centavos = Column(Integer, nullable=False, default=0, server_default="0")
    emergency_wallet_centavos = Column(Integer, nullable=False, default=0, server_default="0")
    # Monthly vesting thresholds (Agreement Rev. 5A §5.5): how many consecutive
    # cleared monthly payments a subscriber needs before each class of benefit
    # opens. Emergency opens first, planned services later — see
    # domain/subscription_utils.py.
    #
    # Held per plan rather than looked up by plan NAME on purpose. A name match is
    # what made the Emergency Wallet unreachable for months
    # (reimbursement_utils.EMERGENCY_CATEGORY_NAMES), and §5.5 explicitly allows
    # these to change "through an officially approved Plan Schedule", so they are
    # data, not code. 0 = no waiting period.
    #
    # Annual members are never gated (§5.9); these apply only where a Subscription
    # row exists for the pet.
    vesting_planned_payments = Column(Integer, nullable=False, default=0, server_default="0")
    vesting_emergency_payments = Column(Integer, nullable=False, default=0, server_default="0")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    plan_services = relationship("PlanService", back_populates="plan", cascade="all, delete-orphan")
    change_events = relationship("PlanChangeEvent", cascade="all, delete-orphan")


class PlanService(Base):
    """Defines how many sessions of each service type a plan grants."""
    __tablename__ = "plan_services"
    __table_args__ = (
        # One row per (plan, service_type) — prevents duplicate category rows when
        # an admin adds a category that a concurrent request also added.
        UniqueConstraint("plan_id", "service_type_id", name="uq_plan_service"),
    )

    id = Column(String, primary_key=True, default=gen_uuid)
    plan_id = Column(String, ForeignKey("plans.id"), nullable=False)
    service_type_id = Column(String, ForeignKey("service_types.id"), nullable=False)
    sessions = Column(Integer, nullable=False, default=0)
    # Annual reimbursement ceiling (in centavos) this plan grants for this service
    # category. 0 = category is not reimbursable under this plan.
    reimbursement_cap_centavos = Column(Integer, nullable=False, default=0)

    plan = relationship("Plan", back_populates="plan_services")
    service_type = relationship("ServiceType")


class ClinicPartner(Base):
    __tablename__ = "clinic_partners"

    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, ForeignKey("users.id"), unique=True, nullable=False)
    clinic_name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    address = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="clinic_partner")

    @property
    def email(self):
        return self.user.email if self.user else None


class ReimbursementProvider(Base):
    """A clinic/groomer verified to receive a reimbursement payout directly
    (member never fronts cash). Deliberately NOT related to ClinicPartner —
    that table is a login-capable clinic account used only by the (currently
    flag-disabled) booking feature. A provider here is just identity + payout
    details, admin-managed, no login. See Reimbursement.payout_target."""
    __tablename__ = "reimbursement_providers"

    id = Column(String, primary_key=True, default=gen_uuid)
    name = Column(String, nullable=False)
    category = Column(String, nullable=True)  # admin reference only, e.g. "Grooming Salon"
    phone = Column(String, nullable=True)
    address = Column(Text, nullable=True)
    payout_method = Column(String, nullable=True)
    payout_account_name = Column(String, nullable=True)
    payout_account_number = Column(String, nullable=True)
    payout_bank_name = Column(String, nullable=True)  # only for bank transfers
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class DirectoryProvider(Base):
    """A public listing in the website's pet-care directory — a community
    resource, NOT a partnership and NOT a payout target.

    Deliberately separate from ReimbursementProvider: `is_active` on that table
    is the control that authorises MetroPaws to wire money to a business. If the
    two shared a row, publishing a listing to the website would also make it
    payable, and this table is read by an UNAUTHENTICATED public endpoint, so it
    must not carry payout details at all.

    `services` holds slugs from directory_taxonomy.SERVICE_LABELS, not the
    client's free-text category line, so one place can appear under several of
    the website's filters. `is_partner` only flips the card's badge from
    "Community Directory" to "MetroPaws Partner"; it grants nothing."""
    __tablename__ = "directory_providers"

    id = Column(String, primary_key=True, default=gen_uuid)
    name = Column(String, nullable=False)
    services = Column(JSON, nullable=False, default=list)
    address = Column(Text, nullable=True)
    phone = Column(String, nullable=True)
    email = Column(String, nullable=True)
    website = Column(String, nullable=True)
    hours = Column(Text, nullable=True)
    # Explicit Google Maps pin. Blank is fine — the website builds a maps search
    # from name + address, so every card gets a working map button either way.
    map_url = Column(Text, nullable=True)
    is_partner = Column(Boolean, default=False, nullable=False)
    is_published = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class PaymentStatus(str, enum.Enum):
    pending = "pending"
    paid = "paid"
    failed = "failed"
    expired = "expired"


class Payment(Base):
    __tablename__ = "payments"

    id = Column(String, primary_key=True, default=gen_uuid)
    member_id = Column(String, ForeignKey("members.id"), nullable=False, index=True)
    plan_id = Column(String, ForeignKey("plans.id"), nullable=False)
    pet_id = Column(String, ForeignKey("pets.id"), nullable=True)
    amount_php = Column(Integer, nullable=False)
    # Pack Discount applied at checkout (whole pesos, 0 = none). amount_php is
    # the FINAL charged amount; full price = amount_php + discount_php. Kept on
    # the row so receipts/audits can reconstruct the price without re-running
    # the eligibility rule against state that has since changed.
    discount_php = Column(Integer, nullable=False, default=0, server_default="0")
    currency = Column(String, nullable=False, default="PHP")
    provider = Column(String, nullable=False, default="paymongo")
    provider_source_id = Column(String, nullable=True, index=True)
    provider_payment_id = Column(String, nullable=True, index=True)
    status = Column(Enum(PaymentStatus), default=PaymentStatus.pending, nullable=False)
    checkout_url = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    paid_at = Column(DateTime(timezone=True), nullable=True)

    member = relationship("Member")
    plan = relationship("Plan")
    pet = relationship("Pet")


class SubscriptionStatus(str, enum.Enum):
    """Lifecycle of a monthly installment arrangement.

    Deliberately NOT the member-facing labels of Agreement §5.7 ("Vesting in
    Progress", "Fully Service-Eligible", ...). Those are derived from this plus
    the payment counter, the same way plan_term_utils derives plan_status rather
    than storing it — a stored label drifts from the facts that produce it.
    """
    pending_first_payment = "pending_first_payment"
    active = "active"
    suspended = "suspended"
    cancelled = "cancelled"


class Subscription(Base):
    """A monthly installment arrangement for ONE pet's plan (Agreement §5.2–§5.8).

    Per pet rather than per member, because plans are granted per pet and Payment
    already carries pet_id: a member may hold one pet annually and another
    monthly.

    **An annual member has no row here at all.** That absence is how §5.9 is
    expressed in code — no subscription, no vesting gate — so nothing has to
    special-case the annual path.

    One row per pet, reused if a member resubscribes after cancelling. History
    lives in `payments`, which is the audited record; keeping a single row avoids
    the duplicate-row class of bug that PetService and PlanService both had to
    grow UNIQUE constraints to stop.
    """
    __tablename__ = "subscriptions"
    __table_args__ = (
        UniqueConstraint("pet_id", name="uq_subscription_pet"),
    )

    id         = Column(String, primary_key=True, default=gen_uuid)
    member_id  = Column(String, ForeignKey("members.id"), nullable=False, index=True)
    pet_id     = Column(String, ForeignKey("pets.id"), nullable=False)
    plan_id    = Column(String, ForeignKey("plans.id"), nullable=False)
    status     = Column(
        Enum(SubscriptionStatus),
        default=SubscriptionStatus.pending_first_payment,
        nullable=False,
        index=True,
    )

    # Consecutive, uninterrupted, successfully cleared payments (§5.4). Reset or
    # restored on default per §5.6 — that policy is a business decision and is
    # not implemented here.
    consecutive_payments = Column(Integer, nullable=False, default=0, server_default="0")
    last_payment_at      = Column(DateTime(timezone=True), nullable=True)
    next_due_on          = Column(Date, nullable=True)

    # The dates each class of benefit became available, stamped when the counter
    # crosses the plan's threshold. §5.8 makes these load-bearing rather than
    # cosmetic: a service obtained BEFORE the applicable eligibility date is never
    # payable, "even if the Member later completes the required monthly
    # installments". A counter alone cannot answer that; it has no memory of when.
    emergency_eligible_since = Column(Date, nullable=True)
    planned_eligible_since   = Column(Date, nullable=True)

    started_at   = Column(DateTime(timezone=True), server_default=func.now())
    suspended_at = Column(DateTime(timezone=True), nullable=True)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)
    created_at   = Column(DateTime(timezone=True), server_default=func.now())
    updated_at   = Column(DateTime(timezone=True), onupdate=func.now())

    member = relationship("Member")
    pet    = relationship("Pet")
    plan   = relationship("Plan")


class AppSetting(Base):
    __tablename__ = "app_settings"

    key = Column(String, primary_key=True)
    value = Column(String, nullable=False)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class Promo(Base):
    """A member-facing event or promo shown in the mobile app's Events tab
    (the Book tab's stand-in while booking is on standby — no partner clinics
    yet). Admin-managed via the website; members only read."""
    __tablename__ = "promos"

    id = Column(String, primary_key=True, default=gen_uuid)
    title = Column(String, nullable=False)
    body = Column(Text, nullable=True)
    type = Column(String, nullable=False, default="promo")  # 'event' | 'promo'
    event_date = Column(DateTime(timezone=True), nullable=True)  # events only
    location = Column(String, nullable=True)                     # events only
    link_url = Column(String, nullable=True)   # e.g. FB post / signup form
    image_url = Column(String, nullable=True)  # optional banner
    is_published = Column(Boolean, default=True, nullable=False)
    sort_order = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class FAQ(Base):
    __tablename__ = "faqs"

    id = Column(String, primary_key=True, default=gen_uuid)
    question = Column(Text, nullable=False)
    answer = Column(Text, nullable=False)
    sort_order = Column(Integer, default=0, nullable=False)
    is_published = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id = Column(String, primary_key=True, default=gen_uuid)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    token = Column(String, unique=True, nullable=False, index=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User")


class PawPointsActivityType(str, enum.Enum):
    membership_activation     = "membership_activation"
    pet_profile_completed     = "pet_profile_completed"
    service_deployed_vet      = "service_deployed_vet"
    service_deployed_grooming = "service_deployed_grooming"
    membership_renewal        = "membership_renewal"
    admin_manual_award        = "admin_manual_award"


class PawPointsTransaction(Base):
    __tablename__ = "paw_points_transactions"

    id            = Column(String, primary_key=True, default=gen_uuid)
    member_id     = Column(String, ForeignKey("members.id"), nullable=False, index=True)
    points        = Column(Integer, nullable=False)
    activity_type = Column(Enum(PawPointsActivityType), nullable=False)
    reference_id  = Column(String, nullable=True)
    notes         = Column(Text, nullable=True)
    created_at    = Column(DateTime(timezone=True), server_default=func.now())

    member = relationship("Member", foreign_keys=[member_id])


class PawPointsReward(Base):
    __tablename__ = "paw_points_rewards"

    id              = Column(String, primary_key=True, default=gen_uuid)
    name            = Column(String, nullable=False)
    description     = Column(Text)
    points_required = Column(Integer, nullable=False)
    reward_type     = Column(String, nullable=False, default="merchandise")
    is_active       = Column(Boolean, default=True)
    sort_order      = Column(Integer, default=0)


class ReservationStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class FoundingReservation(Base):
    __tablename__ = "founding_reservations"

    id = Column(String, primary_key=True, default=gen_uuid)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    email = Column(String, nullable=False, index=True)
    phone = Column(String, nullable=True)
    barangay = Column(String, nullable=False)
    message = Column(Text, nullable=True)
    status = Column(Enum(ReservationStatus), default=ReservationStatus.pending, nullable=False)
    admin_notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ReimbursementStatus(str, enum.Enum):
    pending      = "pending"        # submitted, awaiting review
    under_review = "under_review"   # admin is checking it
    needs_info   = "needs_info"     # admin asked for a clearer/complete receipt
    approved     = "approved"       # eligible; approved_amount set
    rejected     = "rejected"       # not eligible / incomplete
    paid         = "paid"           # offline reimbursement released


class PayoutTarget(str, enum.Enum):
    member   = "member"    # default — MetroPaws reimburses the member (existing flow)
    provider = "provider"  # MetroPaws pays the ReimbursementProvider directly


class Reimbursement(Base):
    """A member's claim to be reimbursed for a service paid out-of-pocket, OR
    (when payout_target == provider) a pre-authorization request to pay a
    verified ReimbursementProvider directly for an upcoming scheduled service —
    see reimbursement_utils.is_direct_pay_eligible_category.

    Money is stored in integer centavos (never float, never whole-peso).
    The app is the system of record only — actual payout happens offline and is
    recorded by an admin via the `paid` status. See
    docs/REIMBURSEMENT_FEATURE_PLAN.md.
    """
    __tablename__ = "reimbursements"

    id                       = Column(String, primary_key=True, default=gen_uuid)
    member_id                = Column(String, ForeignKey("members.id"), nullable=False, index=True)
    pet_id                   = Column(String, ForeignKey("pets.id"), nullable=False)
    service_type_id          = Column(String, ForeignKey("service_types.id"), nullable=False)
    provider_name            = Column(String, nullable=False)
    service_date             = Column(Date, nullable=False)
    claimed_amount_centavos  = Column(Integer, nullable=False)
    approved_amount_centavos = Column(Integer, nullable=True)
    receipt_url              = Column(String, nullable=False)
    receipt_reference        = Column(String, nullable=True)
    receipt_sha256           = Column(String, nullable=True, index=True)  # duplicate-receipt detection
    member_notes             = Column(Text, nullable=True)
    status                   = Column(Enum(ReimbursementStatus), default=ReimbursementStatus.pending, nullable=False, index=True)
    admin_notes              = Column(Text, nullable=True)
    reviewed_by_admin_id     = Column(String, ForeignKey("users.id"), nullable=True)
    reviewed_at              = Column(DateTime(timezone=True), nullable=True)
    paid_by_admin_id         = Column(String, ForeignKey("users.id"), nullable=True)
    paid_at                  = Column(DateTime(timezone=True), nullable=True)
    paid_reference           = Column(String, nullable=True)  # GCash/bank txn ref for reconciliation
    payout_target            = Column(Enum(PayoutTarget), default=PayoutTarget.member, nullable=False)
    provider_id              = Column(String, ForeignKey("reimbursement_providers.id"), nullable=True)
    created_at               = Column(DateTime(timezone=True), server_default=func.now())
    updated_at               = Column(DateTime(timezone=True), onupdate=func.now())

    member       = relationship("Member")
    pet          = relationship("Pet")
    service_type = relationship("ServiceType")
    provider     = relationship("ReimbursementProvider")
    reviewed_by  = relationship("User", foreign_keys=[reviewed_by_admin_id])
    paid_by      = relationship("User", foreign_keys=[paid_by_admin_id])
    events       = relationship(
        "ReimbursementEvent",
        back_populates="reimbursement",
        cascade="all, delete-orphan",
        order_by="ReimbursementEvent.created_at",
    )


class Notification(Base):
    """In-app notification for a member (bell icon). Created alongside status
    emails; generic so future features (bookings, points) can reuse it."""
    __tablename__ = "notifications"

    id           = Column(String, primary_key=True, default=gen_uuid)
    member_id    = Column(String, ForeignKey("members.id"), nullable=False, index=True)
    title        = Column(String, nullable=False)
    body         = Column(Text, nullable=True)
    type         = Column(String, nullable=False, default="general")  # e.g. 'reimbursement'
    reference_id = Column(String, nullable=True)  # e.g. the claim id
    is_read      = Column(Boolean, default=False, nullable=False)
    created_at   = Column(DateTime(timezone=True), server_default=func.now())

    member = relationship("Member")


class ReimbursementEvent(Base):
    """Append-only audit trail of every reimbursement status transition."""
    __tablename__ = "reimbursement_events"

    id               = Column(String, primary_key=True, default=gen_uuid)
    reimbursement_id = Column(String, ForeignKey("reimbursements.id"), nullable=False, index=True)
    from_status      = Column(String, nullable=True)
    to_status        = Column(String, nullable=False)
    actor_user_id    = Column(String, ForeignKey("users.id"), nullable=True)
    note             = Column(Text, nullable=True)
    created_at       = Column(DateTime(timezone=True), server_default=func.now())

    reimbursement = relationship("Reimbursement", back_populates="events")
    actor         = relationship("User", foreign_keys=[actor_user_id])


class PlanChangeEvent(Base):
    """Append-only audit trail of admin edits to a plan's benefit config.

    Currently records reimbursement-cap changes (who changed which plan+category,
    and the old→new value). Money values are stored as centavos strings so the
    same table can log non-money fields later. See admin.update_plan."""
    __tablename__ = "plan_change_events"

    id              = Column(String, primary_key=True, default=gen_uuid)
    plan_id         = Column(String, ForeignKey("plans.id"), nullable=False, index=True)
    service_type_id = Column(String, ForeignKey("service_types.id"), nullable=True)
    field           = Column(String, nullable=False)
    from_value      = Column(String, nullable=True)
    to_value        = Column(String, nullable=True)
    actor_user_id   = Column(String, ForeignKey("users.id"), nullable=True)
    created_at      = Column(DateTime(timezone=True), server_default=func.now())

    actor        = relationship("User", foreign_keys=[actor_user_id])
    service_type = relationship("ServiceType")

