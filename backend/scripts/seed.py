"""Seed the reference data a fresh database needs: service categories, plans and
their session/cap rows, app settings, the admin account, the PawPoints rewards
catalogue, and the published FAQs.

Every step is idempotent — it inserts only what is missing — so re-running is
safe and is how you top a database up after adding a new default.

Nothing happens on import. Run it explicitly, and mind which database
``APP_ENV`` resolves to:

    python -m scripts.seed                          # dev, the default
    cmd /c "set APP_ENV=prod&& python -m scripts.seed"

Sample clinic logins are created only when SEED_CLINIC_PASSWORD is set, so
production never gets accounts whose password lives in this repo.
"""
from app import config
from app import models
from app.auth import hash_password
from app.database import SessionLocal, engine

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

def seed_service_types(db) -> None:
    """The service categories everything else keys off, by name."""
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

def seed_plans(db) -> None:
    """The three membership tiers and their two wallet pools."""
    for plan_data in PLANS:
        existing = db.query(models.Plan).filter(models.Plan.name == plan_data["name"]).first()
        if not existing:
            db.add(models.Plan(**plan_data))

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

DEFAULT_ADMIN_EMAIL = "admin@metropaws.ph"

DEFAULT_APP_SETTINGS = [
    ("payments_enabled", "true"),
    ("founding_50_enabled", "true"),
    ("founding_50_limit", "50"),
    # Booking on standby until partner clinics exist (client, 2026-07-09).
    ("booking_enabled", "false"),
]


def seed_plan_services(db) -> None:
    """Each plan's session grants and legacy per-category caps."""
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


def seed_app_settings(db) -> None:
    """Feature switches, at their launch defaults. Admin edits are never
    overwritten — a key that already exists is left alone."""
    for key, default_val in DEFAULT_APP_SETTINGS:
        if not db.query(models.AppSetting).filter(models.AppSetting.key == key).first():
            db.add(models.AppSetting(key=key, value=default_val))


def admin_email() -> str:
    return config.env("SEED_ADMIN_EMAIL", DEFAULT_ADMIN_EMAIL)


def seed_admin_user(db) -> None:
    """The first admin login."""
    admin_email_address = admin_email()
    admin_password = config.require("SEED_ADMIN_PASSWORD")

    if not db.query(models.User).filter(models.User.email == admin_email_address).first():
        admin_user = models.User(
            email=admin_email_address,
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

def seed_sample_clinics(db) -> None:
    """Demo/dev data only. Requires SEED_CLINIC_PASSWORD to be set explicitly —
    without it the whole step is skipped, so prod never gets sample clinic
    logins with a password that lives in this repo."""
    clinic_password = config.env("SEED_CLINIC_PASSWORD")
    if not clinic_password:
        print("    SEED_CLINIC_PASSWORD not set — skipping sample clinic accounts.")
        return
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

# The PawPoints rewards catalogue, from the Member Manual. Absorbed from
# migrations/add_paw_points.sql, which had to be pasted into the Supabase SQL
# editor by hand and could not be re-run: its ids came from gen_random_uuid(),
# so ON CONFLICT DO NOTHING never matched and a second run duplicated all seven.
# Matching on name here makes it idempotent like every other step.
PAW_POINTS_REWARDS = [
    ("Digital Responsible Fur Parent Badge", "Low-cost recognition reward", 250, "recognition", 1),
    ("MetroPaws Pet Tag or Sticker Pack", "Subject to availability", 500, "merchandise", 2),
    ("Pet Wellness Checklist Kit or Event Priority Slot", "Designed to support wellness engagement", 750, "merchandise", 3),
    ("PHP 100 Wellness Credit", "Subject to reward budget and program rules", 1000, "credit", 4),
    ("Grooming Add-On or Nail Trim Voucher", "Partner availability may apply", 1500, "voucher", 5),
    ("Premium Member Gift Pack or VIP Event Access", "Ideal for Premium and loyal members", 2500, "merchandise", 6),
    ("Special Annual Recognition Reward", "For top engaged members only", 5000, "recognition", 7),
]


def seed_paw_points_rewards(db) -> None:
    """What members can redeem points for."""
    for name, description, points, reward_type, sort_order in PAW_POINTS_REWARDS:
        if db.query(models.PawPointsReward).filter(models.PawPointsReward.name == name).first():
            continue
        db.add(models.PawPointsReward(
            name=name,
            description=description,
            points_required=points,
            reward_type=reward_type,
            is_active=True,
            sort_order=sort_order,
        ))


def seed_faqs(db) -> None:
    """The published FAQ list the website and app both read."""
    for faq_data in FAQS:
        existing = db.query(models.FAQ).filter(models.FAQ.question == faq_data["question"]).first()
        if not existing:
            db.add(models.FAQ(**faq_data))


# Order matters: plan services look plans and service types up by name.
SEEDERS = (
    seed_service_types,
    seed_plans,
    seed_plan_services,
    seed_app_settings,
    seed_admin_user,
    seed_paw_points_rewards,
    seed_sample_clinics,
    seed_faqs,
)


def run_all(db, announce=None) -> None:
    """Run every seeder in order, committing after each.

    The commit between steps is load-bearing, not tidiness: the session runs
    with autoflush=False, so seed_plan_services cannot see the plans
    seed_plans added until they are pushed.
    """
    for seeder in SEEDERS:
        if announce:
            announce(seeder.__name__)
        seeder(db)
        db.commit()


def main() -> None:
    print(f"Seeding {config.database_target()}\n")
    models.Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        run_all(db, announce=lambda name: print(f"  {name} ...", flush=True))
    finally:
        db.close()
    print(f"\nSeed complete. Admin account: {admin_email()}")


if __name__ == "__main__":
    main()
