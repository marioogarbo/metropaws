"""Membership plans: pricing, wallets, and the per-category session and
reimbursement-cap rows, with every money change written to the audit trail."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas, auth as auth_utils
from app.database import get_db

router = APIRouter(tags=["admin"])


@router.get("/plans", response_model=list[schemas.PlanOut])
def list_plans_admin(
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    return db.query(models.Plan).order_by(models.Plan.sort_order).all()


@router.post("/plans", response_model=schemas.PlanOut, status_code=201)
def create_plan(
    payload: schemas.PlanCreate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    plan = models.Plan(**payload.model_dump())
    db.add(plan)
    db.commit()
    db.refresh(plan)
    return plan


def _apply_service_caps(
    db: Session,
    plan: models.Plan,
    caps: list[dict],
    actor: models.User,
) -> None:
    """Apply reimbursement-cap / session edits to the plan's categories, creating a
    plan_services row when the category isn't on the plan yet, and record an audit
    entry for each actual change.

    Adding a category takes effect immediately for reimbursement (the wallet and
    claim eligibility read plan_services live), but session credits are granted
    only at activation/renewal — existing pets on the plan are NOT backfilled here.
    """
    rows = {ps.service_type_id: ps for ps in plan.plan_services}
    for cap in caps:
        service_type_id = cap["service_type_id"]
        new_val = cap["reimbursement_cap_centavos"]
        new_sessions = cap.get("sessions")
        ps = rows.get(service_type_id)

        if ps is None:
            # New category on this plan — validate the ServiceType exists first.
            exists = (
                db.query(models.ServiceType)
                .filter(models.ServiceType.id == service_type_id)
                .first()
            )
            if not exists:
                raise HTTPException(
                    status_code=422,
                    detail="A reimbursement cap targets a service category that doesn't exist.",
                )
            sessions = new_sessions or 0
            ps = models.PlanService(
                plan_id=plan.id,
                service_type_id=service_type_id,
                sessions=sessions,
                reimbursement_cap_centavos=new_val,
            )
            db.add(ps)
            rows[service_type_id] = ps
            db.add(
                models.PlanChangeEvent(
                    plan_id=plan.id,
                    service_type_id=service_type_id,
                    field="category_added",
                    from_value=None,
                    to_value=f"sessions={sessions};cap={new_val}",
                    actor_user_id=actor.id,
                )
            )
            continue

        # Existing category — update the cap and/or sessions, auditing each change.
        old_val = ps.reimbursement_cap_centavos or 0
        if old_val != new_val:
            ps.reimbursement_cap_centavos = new_val
            db.add(
                models.PlanChangeEvent(
                    plan_id=plan.id,
                    service_type_id=service_type_id,
                    field="reimbursement_cap_centavos",
                    from_value=str(old_val),
                    to_value=str(new_val),
                    actor_user_id=actor.id,
                )
            )
        if new_sessions is not None and new_sessions != (ps.sessions or 0):
            old_sessions = ps.sessions or 0
            ps.sessions = new_sessions
            db.add(
                models.PlanChangeEvent(
                    plan_id=plan.id,
                    service_type_id=service_type_id,
                    field="sessions",
                    from_value=str(old_sessions),
                    to_value=str(new_sessions),
                    actor_user_id=actor.id,
                )
            )


@router.put("/plans/{plan_id}", response_model=schemas.PlanOut)
def update_plan(
    plan_id: str,
    payload: schemas.PlanUpdate,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    plan = db.query(models.Plan).filter(models.Plan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    data = payload.model_dump(exclude_unset=True)
    # service_caps isn't a Plan column — pull it out and apply to plan_services rows.
    service_caps = data.pop("service_caps", None)
    # Audit wallet changes (money config) before applying them — one event per
    # pool that changed.
    for field in ("reimbursement_wallet_centavos", "emergency_wallet_centavos"):
        new_wallet = data.get(field)
        old_wallet = getattr(plan, field) or 0
        if new_wallet is not None and new_wallet != old_wallet:
            db.add(
                models.PlanChangeEvent(
                    plan_id=plan.id,
                    service_type_id=None,
                    field=field,
                    from_value=str(old_wallet),
                    to_value=str(new_wallet),
                    actor_user_id=current_user.id,
                )
            )
    for k, v in data.items():
        setattr(plan, k, v)
    if service_caps:
        _apply_service_caps(db, plan, service_caps, current_user)

    db.commit()
    db.refresh(plan)
    return plan


@router.delete("/plans/{plan_id}", status_code=204)
def delete_plan(
    plan_id: str,
    current_user: models.User = Depends(auth_utils.require_admin),
    db: Session = Depends(get_db),
):
    plan = db.query(models.Plan).filter(models.Plan.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    db.delete(plan)
    db.commit()
