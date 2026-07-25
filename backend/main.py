from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
import os

load_dotenv()

from database import engine
import models
from routers import auth, members, pets, admin, plans, clinic, payments, settings, paw_points, reimbursements, exports
from routers.faqs import public_router as faqs_public, admin_router as faqs_admin
from routers.promos import public_router as promos_public, admin_router as promos_admin
from routers.founding_reservations import public_router as reservations_public, admin_router as reservations_admin

models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="MetroPaws API",
    description="Membership, booking, and clinic management for Metropaws Wellness Club Philippines",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

upload_dir = os.getenv("UPLOAD_DIR", "uploads")
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


@app.get("/")
def root():
    return {"message": "MetroPaws API is live", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "ok"}
