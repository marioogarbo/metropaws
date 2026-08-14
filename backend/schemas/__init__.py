"""Request and response shapes for the whole API.

This package replaced a single 1,000-line schemas.py. Every name is
re-exported here, so `import schemas` and `schemas.PetOut` work exactly as
they did — no caller needed changing.

Modules are layered so imports flow one way:

    validators -> services -> pets, plans -> members -> bookings -> clinics
    providers -> reimbursements

Keep it that way when adding a shape: if two modules need each other, the
shared piece belongs in the lower one.
"""
from schemas.validators import (
    validate_ph_phone,
)
from schemas.auth import (
    UserRole,
    RegisterRequest,
    LoginRequest,
    TokenResponse,
    ForgotPasswordRequest,
    ResetPasswordRequest,
)
from schemas.services import (
    ServiceTypeOut,
    MemberServiceOut,
    PetServiceOut,
    DeployServiceRequest,
    ServiceLogOut,
    AssignServiceRequest,
    ServiceLogBriefOut,
)
from schemas.plans import (
    SelectPlanRequest,
    PlanServiceOut,
    PlanServiceCapUpdate,
    PlanCreate,
    PlanUpdate,
    PlanOut,
)
from schemas.pets import (
    PetCreate,
    PetUpdate,
    PetOut,
    PetActivatePlanRequest,
    PetWithHistoryOut,
)
from schemas.members import (
    MemberUpdate,
    MemberOut,
    MemberDirectPayUpdate,
    MemberSummary,
    MemberBriefOut,
    AdminMemberCreate,
)
from schemas.bookings import (
    ClinicBriefOut,
    BookingStatus,
    BookingCreate,
    BookingOut,
    AdminBookingOut,
    ClinicBookingOut,
)
from schemas.clinics import (
    ClinicPartnerCreate,
    ClinicPartnerUpdate,
    ClinicPartnerOut,
    ClinicScanResult,
)
from schemas.providers import (
    ReimbursementProviderCreate,
    ReimbursementProviderUpdate,
    ReimbursementProviderOut,
    ReimbursementProviderBriefOut,
)
from schemas.payments import (
    CheckoutRequest,
    CheckoutResponse,
    PlanQuoteOut,
    PaymentOut,
    AdminPaymentOut,
)
from schemas.reimbursements import (
    ReimbursementEventOut,
    ReimbursementOut,
    ReimbursementPetOut,
    ReimbursementMemberOut,
    AdminReimbursementOut,
    ReimbursementReviewRequest,
    MarkPaidRequest,
    WalletPetOut,
    WalletOut,
)
from schemas.paw_points import (
    PawPointsBalanceOut,
    PawPointsTransactionOut,
    PawRewardOut,
    PawAwardRequest,
)
from schemas.content import (
    FAQCreate,
    FAQUpdate,
    FAQOut,
    FAQReorderRequest,
    PromoCreate,
    PromoUpdate,
    PromoOut,
)
from schemas.directory import (
    DirectoryProviderCreate,
    DirectoryProviderUpdate,
    DirectoryProviderOut,
)
from schemas.reservations import (
    FoundingReservationCreate,
    FoundingReservationStatusUpdate,
    FoundingReservationOut,
)
from schemas.settings import (
    AppSettingOut,
    PaymentsEnabledOut,
    PaymentsEnabledUpdate,
    Founding50Out,
    Founding50Update,
    FoundingStatusUpdate,
    MobileConfigOut,
    BookingEnabledUpdate,
    DirectProviderPaymentUpdate,
    PackDiscountOut,
    PackDiscountUpdate,
)
from schemas.notifications import (
    NotificationOut,
)

__all__ = [
    "AdminBookingOut",
    "AdminMemberCreate",
    "AdminPaymentOut",
    "AdminReimbursementOut",
    "AppSettingOut",
    "AssignServiceRequest",
    "BookingCreate",
    "BookingEnabledUpdate",
    "BookingOut",
    "BookingStatus",
    "CheckoutRequest",
    "CheckoutResponse",
    "ClinicBookingOut",
    "ClinicBriefOut",
    "ClinicPartnerCreate",
    "ClinicPartnerOut",
    "ClinicPartnerUpdate",
    "ClinicScanResult",
    "DeployServiceRequest",
    "DirectProviderPaymentUpdate",
    "DirectoryProviderCreate",
    "DirectoryProviderOut",
    "DirectoryProviderUpdate",
    "FAQCreate",
    "FAQOut",
    "FAQReorderRequest",
    "FAQUpdate",
    "ForgotPasswordRequest",
    "Founding50Out",
    "Founding50Update",
    "FoundingReservationCreate",
    "FoundingReservationOut",
    "FoundingReservationStatusUpdate",
    "FoundingStatusUpdate",
    "LoginRequest",
    "MarkPaidRequest",
    "MemberBriefOut",
    "MemberDirectPayUpdate",
    "MemberOut",
    "MemberServiceOut",
    "MemberSummary",
    "MemberUpdate",
    "MobileConfigOut",
    "NotificationOut",
    "PackDiscountOut",
    "PackDiscountUpdate",
    "PawAwardRequest",
    "PawPointsBalanceOut",
    "PawPointsTransactionOut",
    "PawRewardOut",
    "PaymentOut",
    "PaymentsEnabledOut",
    "PaymentsEnabledUpdate",
    "PetActivatePlanRequest",
    "PetCreate",
    "PetOut",
    "PetServiceOut",
    "PetUpdate",
    "PetWithHistoryOut",
    "PlanCreate",
    "PlanOut",
    "PlanQuoteOut",
    "PlanServiceCapUpdate",
    "PlanServiceOut",
    "PlanUpdate",
    "PromoCreate",
    "PromoOut",
    "PromoUpdate",
    "RegisterRequest",
    "ReimbursementEventOut",
    "ReimbursementMemberOut",
    "ReimbursementOut",
    "ReimbursementPetOut",
    "ReimbursementProviderBriefOut",
    "ReimbursementProviderCreate",
    "ReimbursementProviderOut",
    "ReimbursementProviderUpdate",
    "ReimbursementReviewRequest",
    "ResetPasswordRequest",
    "SelectPlanRequest",
    "ServiceLogBriefOut",
    "ServiceLogOut",
    "ServiceTypeOut",
    "TokenResponse",
    "UserRole",
    "WalletOut",
    "WalletPetOut",
    "validate_ph_phone",
]
