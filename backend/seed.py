"""Run once to seed default service types and an admin account."""
from database import SessionLocal, engine
import models, os
from auth import hash_password
from dotenv import load_dotenv

load_dotenv()

models.Base.metadata.create_all(bind=engine)

db = SessionLocal()

SERVICE_TYPES = [
    {"name": "Grooming", "description": "Full grooming session", "icon": "cut"},
    {"name": "Vaccines", "description": "Vaccine administration visit", "icon": "vaccines"},
    {"name": "Emergency Stabilization", "description": "Emergency vet stabilization visit", "icon": "emergency"},
    {"name": "Full Grooming", "description": "Premium full grooming with extras", "icon": "spa"},
    {"name": "Semi-Annual Exam", "description": "Bi-annual wellness exam", "icon": "medical_services"},
    {"name": "General Consultation", "description": "General veterinary consultation", "icon": "local_hospital"},
    # Reimbursement wallet buckets — these are the ONLY reimbursable categories.
    # The session categories above carry prepaid sessions but cap 0 (see below).
    {"name": "Preventive Wellness", "description": "Preventive care reimbursement wallet — consultations, vaccines, grooming, wellness checks", "icon": "health_and_safety"},
    {"name": "Emergency", "description": "Emergency care reimbursement wallet", "icon": "emergency"},
]

for st_data in SERVICE_TYPES:
    existing = db.query(models.ServiceType).filter(models.ServiceType.name == st_data["name"]).first()
    if not existing:
        db.add(models.ServiceType(**st_data))

# Final plan spec (2026-07) — keep in sync with the live DB (admin panel edits)
# and the website pricing page.
PLANS = [
    {
        "name": "Standard",
        "price": 2999,
        "price_monthly": 300,
        "tagline": "Smart Pet Parenting Starts Here",
        "features": [
            "Digital Pet Passport",
            "₱2,000 Preventive Wellness Wallet",
            "₱300 Emergency Wallet",
            "Paw Points Rewards",
            "Wellness Reminders",
            "Community Access",
            '"Your wallet goes where your pet needs it most."',
        ],
        "is_featured": False,
        "is_active": True,
        "sort_order": 0,
        # Two pools: Preventive Wellness ₱2,000 + Emergency ₱300.
        "reimbursement_wallet_centavos": 200_000,
        "emergency_wallet_centavos": 30_000,
    },
    {
        "name": "Deluxe",
        "price": 5999,
        "price_monthly": 600,
        "tagline": "More Care. More Flexibility. More Value.",
        "features": [
            "Everything in Standard",
            "₱4,000 Preventive Wellness Wallet",
            "₱900 Emergency Wallet",
            "Higher Paw Points earning",
            "Priority member processing",
            "Member promos and event access",
            '"Your wallet goes where your pet needs it most."',
        ],
        "is_featured": True,
        "is_active": True,
        "sort_order": 1,
        # Two pools: Preventive Wellness ₱4,000 + Emergency ₱900.
        "reimbursement_wallet_centavos": 400_000,
        "emergency_wallet_centavos": 90_000,
    },
    {
        "name": "Premium",
        "price": 9999,
        "price_monthly": 900,
        "tagline": "Premier Pet Wellness Experience",
        "features": [
            "Everything in De Luxe",
            "₱7,000 Preventive Wellness Wallet",
            "₱1,500 Emergency Wallet",
            "Highest Paw Points earning",
            "VIP community access",
            "Concierge-style member support",
            "Premium member recognition",
            '"Your wallet goes where your pet needs it most."',
        ],
        "is_featured": False,
        "is_active": True,
        "sort_order": 2,
        # Two pools: Preventive Wellness ₱7,000 + Emergency ₱1,500.
        "reimbursement_wallet_centavos": 700_000,
        "emergency_wallet_centavos": 150_000,
    },
]

for plan_data in PLANS:
    existing = db.query(models.Plan).filter(models.Plan.name == plan_data["name"]).first()
    if not existing:
        db.add(models.Plan(**plan_data))

db.commit()

# NOTE (2026-07-16): the reimbursement wallet is now TWO pools per plan —
# Plan.reimbursement_wallet_centavos (Preventive Wellness) and
# Plan.emergency_wallet_centavos (Emergency). A claim's service category picks
# the pool ("Emergency" → emergency pool, everything else → preventive). The
# per-category caps below are LEGACY — they no longer gate claims or feed the
# member wallet. Rows are kept only for their session grants.
#
# Plan → Service mappings (keyed by plan name): (service, sessions, reimbursement_cap_centavos)
#
# Two kinds of rows:
#  - Session categories (General Consultation / Grooming / Vaccines): carry the
#    prepaid session counts used by booking + Deploy Service. Cap 0 — NOT
#    reimbursable, so they never appear in the Benefit Wallet.
#  - Wallet buckets (Preventive Wellness / Emergency): sessions 0, carry the
#    annual reimbursement caps sold on the pricing page. These are the ONLY
#    reimbursable categories. Caps in centavos (₱2,000 = 200_000).
#
# Final spec (2026-07): Standard ₱2,000/₱300 · Deluxe ₱4,000/₱900 · Premium ₱7,000/₱1,500.
# Tune per tier here or via admin → Plans → Reimbursement caps.
PLAN_SERVICES = {
    "Standard": [
        ("General Consultation", 2, 0),
        ("Vaccines", 1, 0),
        ("Preventive Wellness", 0, 200_000),
        ("Emergency", 0, 30_000),
    ],
    "Deluxe": [
        ("General Consultation", 4, 0),
        ("Grooming", 2, 0),
        ("Vaccines", 2, 0),
        ("Preventive Wellness", 0, 400_000),
        ("Emergency", 0, 90_000),
    ],
    "Premium": [
        ("General Consultation", 99, 0),
        ("Grooming", 4, 0),
        ("Vaccines", 2, 0),
        ("Preventive Wellness", 0, 700_000),
        ("Emergency", 0, 150_000),
    ],
}

for name, services in PLAN_SERVICES.items():
    plan = db.query(models.Plan).filter(models.Plan.name == name).first()
    if not plan:
        continue
    for svc_name, sessions, cap_centavos in services:
        svc_type = db.query(models.ServiceType).filter(models.ServiceType.name == svc_name).first()
        if not svc_type:
            continue
        existing_ps = db.query(models.PlanService).filter(
            models.PlanService.plan_id == plan.id,
            models.PlanService.service_type_id == svc_type.id,
        ).first()
        if not existing_ps:
            db.add(models.PlanService(
                plan_id=plan.id,
                service_type_id=svc_type.id,
                sessions=sessions,
                reimbursement_cap_centavos=cap_centavos,
            ))

# Default app settings
for key, default_val in [
    ("payments_enabled", "true"),
    ("founding_50_enabled", "true"),
    ("founding_50_limit", "50"),
    # Booking on standby until partner clinics exist (client, 2026-07-09).
    ("booking_enabled", "false"),
]:
    if not db.query(models.AppSetting).filter(models.AppSetting.key == key).first():
        db.add(models.AppSetting(key=key, value=default_val))
db.commit()

admin_email = os.getenv("SEED_ADMIN_EMAIL", "admin@metropaws.ph")
admin_password = os.getenv("SEED_ADMIN_PASSWORD")
if not admin_password:
    raise ValueError("Set SEED_ADMIN_PASSWORD in .env before running seed.py")

if not db.query(models.User).filter(models.User.email == admin_email).first():
    admin_user = models.User(
        email=admin_email,
        password_hash=hash_password(admin_password),
        role=models.UserRole.admin,
    )
    db.add(admin_user)
    db.flush()
    admin_member = models.Member(
        user_id=admin_user.id,
        first_name="Metro",
        last_name="Admin",
    )
    db.add(admin_member)

db.commit()

# Sample clinic partners
CLINICS = [
    {
        "email": "bgc@metropaws.ph",
        "clinic_name": "MetroPaws BGC",
        "address": "G/F, One Bonifacio High Street, BGC, Taguig City",
        "phone": "+63 2 8888 1001",
    },
    {
        "email": "makati@metropaws.ph",
        "clinic_name": "MetroPaws Makati",
        "address": "Level 2, Greenbelt 3, Ayala Ave., Makati City",
        "phone": "+63 2 8888 1002",
    },
    {
        "email": "ortigas@metropaws.ph",
        "clinic_name": "MetroPaws Ortigas",
        "address": "3/F, SM Megamall Building A, Ortigas Center, Mandaluyong",
        "phone": "+63 2 8888 1003",
    },
    {
        "email": "qc@metropaws.ph",
        "clinic_name": "MetroPaws Quezon City",
        "address": "G/F, UP Town Center, Katipunan Ave., Quezon City",
        "phone": "+63 2 8888 1004",
    },
    {
        "email": "alabang@metropaws.ph",
        "clinic_name": "MetroPaws Alabang",
        "address": "2/F, Festival Mall, Filinvest City, Alabang, Muntinlupa",
        "phone": "+63 2 8888 1005",
    },
]

# Demo/dev data only. Requires SEED_CLINIC_PASSWORD to be set explicitly —
# without it the whole block is skipped, so prod never gets sample clinic
# logins with a password that lives in this repo.
clinic_password = os.getenv("SEED_CLINIC_PASSWORD")
if not clinic_password:
    print("SEED_CLINIC_PASSWORD not set — skipping sample clinic accounts.")
else:
    for clinic_data in CLINICS:
        existing_user = db.query(models.User).filter(models.User.email == clinic_data["email"]).first()
        if not existing_user:
            clinic_user = models.User(
                email=clinic_data["email"],
                password_hash=hash_password(clinic_password),
                role=models.UserRole.clinic,
            )
            db.add(clinic_user)
            db.flush()
            db.add(models.ClinicPartner(
                user_id=clinic_user.id,
                clinic_name=clinic_data["clinic_name"],
                address=clinic_data["address"],
                phone=clinic_data["phone"],
            ))

db.commit()

FAQS = [
    {
        "question": "Is MetroPaws free?",
        "answer": "The app is completely free to download and use. Membership fees, if applicable, are arranged directly with your partner clinic — MetroPaws never charges you through the app.",
        "sort_order": 0,
        "is_published": True,
    },
    {
        "question": "What exactly is a session?",
        "answer": "A session is one service visit — a grooming appointment, a vet consultation, a vaccination, or any other service your clinic offers. Your membership includes a set number of sessions per service type, and the app always shows you exactly how many you have left before your next visit.",
        "sort_order": 1,
        "is_published": True,
    },
    {
        "question": "Can I manage multiple pets?",
        "answer": "Yes. Add as many pets as your household has — dogs, cats, or both. Each pet gets their own Digital Pawprint, session tracker, and vaccination record, all under one account.",
        "sort_order": 2,
        "is_published": True,
    },
    {
        "question": "Which clinics in Metro Manila accept MetroPaws?",
        "answer": "We partner with veterinary clinics across Metro Manila — Quezon City, Makati, Pasig, and more. The full up-to-date list of partner clinics is inside the app once you sign in.",
        "sort_order": 3,
        "is_published": True,
    },
    {
        "question": "Does my QR code work without internet?",
        "answer": "Yes. Your Digital Pawprint QR ID is cached on your phone and works offline. You only need an internet connection to sync new sessions or update your pet's profile.",
        "sort_order": 4,
        "is_published": True,
    },
]

for faq_data in FAQS:
    existing = db.query(models.FAQ).filter(models.FAQ.question == faq_data["question"]).first()
    if not existing:
        db.add(models.FAQ(**faq_data))

db.commit()
db.close()
print(f"Seed complete. Admin account: {admin_email}")
