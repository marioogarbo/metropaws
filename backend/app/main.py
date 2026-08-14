from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
import sys

from app import config  # must precede every project import — it populates the environment

from app.database import engine
from app import models
from app.routers import auth, members, pets, admin, plans, clinic, payments, settings, paw_points, reimbursements, exports
from app.routers.faqs import public_router as faqs_public, admin_router as faqs_admin
from app.routers.promos import public_router as promos_public, admin_router as promos_admin
from app.routers.founding_reservations import public_router as reservations_public, admin_router as reservations_admin
from app.routers.directory import public_router as directory_public, admin_router as directory_admin

models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="MetroPaws API",
    description="Membership, booking, and clinic management for Metropaws Wellness Club Philippines",
    version="1.0.0",
)

def cors_settings() -> tuple[list[str], str | None]:
    """Which browser origins may call this API, as (origins, origin_regex).

    This governs the website's browser-side calls only — admin login, password
    reset, and the public founding/pricing forms. The Flutter app is
    unaffected: native HTTP sends no Origin header, so CORS never applies to
    it. Next.js server actions are server-to-server and equally unaffected.

    ALLOWED_ORIGIN_REGEX covers Vercel preview deployments, whose hostname
    changes on every push and so cannot be listed.

    With neither set this falls back to allowing everything, loudly. A missing
    variable locking admins out of production would be a worse failure than a
    permissive default, and the warning makes the state obvious in the logs.
    """
    origins = config.env_list("ALLOWED_ORIGINS")
    origin_regex = config.env("ALLOWED_ORIGIN_REGEX") or None
    if not origins and not origin_regex:
        print("[cors] no ALLOWED_ORIGINS set — allowing every origin", file=sys.stderr)
        return ["*"], None
    return origins, origin_regex


cors_origins, cors_origin_regex = cors_settings()

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_origin_regex=cors_origin_regex,
    # Browsers reject credentialed requests against a wildcard origin, so this
    # is only meaningful once an explicit list is configured.
    allow_credentials=cors_origins != ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

upload_dir = config.env("UPLOAD_DIR", "uploads")
os.makedirs(upload_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=upload_dir), name="uploads")

app.include_router(auth.router)
app.include_router(members.router)
app.include_router(pets.router)
app.include_router(admin.router)
app.include_router(plans.router)
app.include_router(clinic.router)
app.include_router(payments.router)
app.include_router(settings.router)
app.include_router(paw_points.router)
app.include_router(reimbursements.router)
app.include_router(exports.router)
app.include_router(faqs_public)
app.include_router(faqs_admin)
app.include_router(promos_public)
app.include_router(promos_admin)
app.include_router(reservations_public)
app.include_router(reservations_admin)
app.include_router(directory_public)
app.include_router(directory_admin)


@app.get("/")
def root():
    return {"message": "MetroPaws API is live", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "ok"}
