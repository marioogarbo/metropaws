"""Admin API — every route here is behind require_admin.

This package replaced a single 1,347-line routers/admin.py. The URL surface is
unchanged: each module below declares a plain router and this file supplies the
shared /admin prefix, so paths and OpenAPI tags are exactly what they were.
tests/routes_snapshot.json pins that.

Add a new admin area by creating a module here and including it below — not by
growing one of the existing ones past its subject.
"""
from fastapi import APIRouter

from routers.admin import (
    analytics,
    bookings,
    members,
    partners,
    paw_points,
    payments,
    pets,
    plans,
    providers,
    reimbursements,
    services,
)

router = APIRouter(prefix="/admin")

for _module in (
    services,
    members,
    plans,
    partners,
    providers,
    pets,
    bookings,
    analytics,
    payments,
    paw_points,
    reimbursements,
):
    router.include_router(_module.router)
