from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload
from database import get_db
import models, schemas, auth as auth_utils
import plan_term_utils
import storage
from plan_utils import grant_plan_to_pet
from routers.settings import get_payments_enabled
from datetime import datetime

router = APIRouter(prefix="/pets", tags=["pets"])

# Uploads go through the shared storage helper (Supabase Storage when configured,
# else local disk). It resolves the MIME type from the file extension, so
# clients that send application/octet-stream (e.g. Flutter's http package) work.
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_DOC_TYPES = {"image/jpeg", "image/png", "application/pdf"}


def _get_member(current_user: models.User, db: Session) -> models.Member:
    member = db.query(models.Member).filter(models.Member.user_id == current_user.id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member profile not found")
    return member


@router.post("/", response_model=schemas.PetOut, status_code=201)
def create_pet(
    name: str = Form(...),
    sex: str = Form(...),
    species: str = Form(...),
    birth_month: int = Form(...),
    birth_year: int = Form(...),
    birth_day: int = Form(None),
    breed: str = Form(...),
    weight_kg: float = Form(...),
    notes: str = Form(None),
    # Identity photos (MP-FRM-PET-001): front face, full body, and pet+owner
    # are required at registration to establish a verified identity and
    # discourage fraudulent registrations. The remaining 4 angles plus the
    # pet+ID-card photo are optional and added later via update_pet, once the
    # pet (and its QR) exists.
    photo: UploadFile = File(...),
    photo_full_body: UploadFile = File(...),
    photo_with_owner: UploadFile = File(...),
    vax_card: UploadFile = File(None),
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    if sex not in ('male', 'female'):
        raise HTTPException(status_code=422, detail="sex must be 'male' or 'female'")
    if species.lower() not in ('dog', 'cat'):
        raise HTTPException(status_code=422, detail="species must be 'dog' or 'cat'")
    species = species.lower()
    if not (1 <= birth_month <= 12):
        raise HTTPException(status_code=422, detail="birth_month must be between 1 and 12")
    current_year = datetime.now().year
    if not (1990 <= birth_year <= current_year):
        raise HTTPException(status_code=422, detail=f"birth_year must be between 1990 and {current_year}")
    if birth_day is not None and not (1 <= birth_day <= 31):
        raise HTTPException(status_code=422, detail="birth_day must be between 1 and 31")
    if weight_kg <= 0 or weight_kg > 200:
        raise HTTPException(status_code=422, detail="weight_kg must be between 0 and 200")
    if not photo.filename:
        raise HTTPException(status_code=422, detail="A front-facing photo is required")
    if not photo_full_body.filename:
        raise HTTPException(status_code=422, detail="A full-body photo is required")
    if not photo_with_owner.filename:
        raise HTTPException(status_code=422, detail="A photo with the pet's owner is required")
    member = _get_member(current_user, db)

    photo_url = storage.save_upload(photo, "photos", ALLOWED_IMAGE_TYPES)
    photo_full_body_url = storage.save_upload(photo_full_body, "photos", ALLOWED_IMAGE_TYPES)
    photo_with_owner_url = storage.save_upload(photo_with_owner, "photos", ALLOWED_IMAGE_TYPES)

    vax_url = None
    if vax_card and vax_card.filename:
        vax_url = storage.save_upload(vax_card, "vax_cards", ALLOWED_DOC_TYPES)

    pet = models.Pet(
        member_id=member.id,
        name=name,
        species=species,
        breed=breed,
        birth_month=birth_month,
        birth_year=birth_year,
        birth_day=birth_day,
        weight_kg=weight_kg,
        sex=sex,
        notes=notes,
        photo_url=photo_url,
        photo_full_body_url=photo_full_body_url,
        photo_with_owner_url=photo_with_owner_url,
        vax_card_url=vax_url,
    )
    db.add(pet)
    db.commit()
    db.refresh(pet)

    from paw_points_utils import award_points, has_awarded_for_reference
    if not has_awarded_for_reference(db, member.id, "pet_profile_completed", pet.id):
        award_points(
            db,
            member_id=member.id,
            activity_type="pet_profile_completed",
            plan_type=member.plan_type,
            reference_id=pet.id,
            notes=f"Pet profile: {pet.name}",
        )
        db.commit()

    return pet


def _pet_query(db: Session):
    return db.query(models.Pet).options(
        joinedload(models.Pet.pet_services).joinedload(models.PetService.service_type)
    )


@router.get("/", response_model=list[schemas.PetOut])
def list_pets(
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = _get_member(current_user, db)
    return _pet_query(db).filter(models.Pet.member_id == member.id).all()


@router.get("/{pet_id}", response_model=schemas.PetOut)
def get_pet(
    pet_id: str,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = _get_member(current_user, db)
    pet = _pet_query(db).filter(models.Pet.id == pet_id, models.Pet.member_id == member.id).first()
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")
    return pet


@router.put("/{pet_id}", response_model=schemas.PetOut)
def update_pet(
    pet_id: str,
    name: str = Form(None),
    species: str = Form(None),
    breed: str = Form(None),
    birth_month: int = Form(None),
    birth_year: int = Form(None),
    birth_day: int = Form(None),
    weight_kg: float = Form(None),
    sex: str = Form(None),
    notes: str = Form(None),
    photo: UploadFile = File(None),
    photo_full_body: UploadFile = File(None),
    photo_with_owner: UploadFile = File(None),
    photo_left_profile: UploadFile = File(None),
    photo_right_profile: UploadFile = File(None),
    photo_rear: UploadFile = File(None),
    photo_top: UploadFile = File(None),
    photo_with_id_card: UploadFile = File(None),
    vax_card: UploadFile = File(None),
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = _get_member(current_user, db)
    pet = db.query(models.Pet).filter(models.Pet.id == pet_id, models.Pet.member_id == member.id).first()
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")

    if name is not None:
        pet.name = name
    if species is not None:
        if species.lower() not in ('dog', 'cat'):
            raise HTTPException(status_code=422, detail="species must be 'dog' or 'cat'")
        pet.species = species.lower()
    if breed is not None:
        pet.breed = breed
    if birth_month is not None:
        if not (1 <= birth_month <= 12):
            raise HTTPException(status_code=422, detail="birth_month must be between 1 and 12")
        pet.birth_month = birth_month
    if birth_year is not None:
        current_year = datetime.now().year
        if not (1990 <= birth_year <= current_year):
            raise HTTPException(status_code=422, detail=f"birth_year must be between 1990 and {current_year}")
        pet.birth_year = birth_year
    if birth_day is not None:
        if not (1 <= birth_day <= 31):
            raise HTTPException(status_code=422, detail="birth_day must be between 1 and 31")
        pet.birth_day = birth_day
    if weight_kg is not None:
        if weight_kg <= 0 or weight_kg > 200:
            raise HTTPException(status_code=422, detail="weight_kg must be between 0 and 200")
        pet.weight_kg = weight_kg
    if sex is not None:
        if sex not in ('male', 'female'):
            raise HTTPException(status_code=422, detail="sex must be 'male' or 'female'")
        pet.sex = sex
    if notes is not None:
        pet.notes = notes
    if photo and photo.filename:
        pet.photo_url = storage.save_upload(photo, "photos", ALLOWED_IMAGE_TYPES)
    if photo_full_body and photo_full_body.filename:
        pet.photo_full_body_url = storage.save_upload(photo_full_body, "photos", ALLOWED_IMAGE_TYPES)
    if photo_with_owner and photo_with_owner.filename:
        pet.photo_with_owner_url = storage.save_upload(photo_with_owner, "photos", ALLOWED_IMAGE_TYPES)
    if photo_left_profile and photo_left_profile.filename:
        pet.photo_left_profile_url = storage.save_upload(photo_left_profile, "photos", ALLOWED_IMAGE_TYPES)
    if photo_right_profile and photo_right_profile.filename:
        pet.photo_right_profile_url = storage.save_upload(photo_right_profile, "photos", ALLOWED_IMAGE_TYPES)
    if photo_rear and photo_rear.filename:
        pet.photo_rear_url = storage.save_upload(photo_rear, "photos", ALLOWED_IMAGE_TYPES)
    if photo_top and photo_top.filename:
        pet.photo_top_url = storage.save_upload(photo_top, "photos", ALLOWED_IMAGE_TYPES)
    if photo_with_id_card and photo_with_id_card.filename:
        pet.photo_with_id_card_url = storage.save_upload(photo_with_id_card, "photos", ALLOWED_IMAGE_TYPES)
    if vax_card and vax_card.filename:
        pet.vax_card_url = storage.save_upload(vax_card, "vax_cards", ALLOWED_DOC_TYPES)

    db.commit()
    db.refresh(pet)
    return pet


@router.delete("/{pet_id}", status_code=204)
def delete_pet(
    pet_id: str,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    member = _get_member(current_user, db)
    pet = db.query(models.Pet).filter(models.Pet.id == pet_id, models.Pet.member_id == member.id).first()
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")

    # Detach records that reference this pet but must survive its removal.
    # Payments are financial records and ServiceLogs are an append-only audit
    # trail (see backend/CLAUDE.md) — we never delete them, only null the pet
    # link so the FK no longer blocks the delete. PetService rows are owned by
    # the pet and cascade-delete via the relationship.
    db.query(models.Payment).filter(models.Payment.pet_id == pet.id).update(
        {models.Payment.pet_id: None}, synchronize_session=False
    )
    db.query(models.ServiceLog).filter(models.ServiceLog.pet_id == pet.id).update(
        {models.ServiceLog.pet_id: None}, synchronize_session=False
    )

    try:
        db.delete(pet)
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="This pet still has linked records and can't be removed automatically. Please contact support.",
        ) from exc


@router.post("/{pet_id}/activate-plan", response_model=schemas.PetOut)
def activate_plan(
    pet_id: str,
    payload: schemas.PetActivatePlanRequest,
    current_user: models.User = Depends(auth_utils.get_current_user),
    db: Session = Depends(get_db),
):
    """Activate a plan for a specific pet. When payments are disabled, grants services
    immediately. When payments are enabled, use POST /payments/checkout with pet_id instead."""
    member = _get_member(current_user, db)
    pet = _pet_query(db).filter(models.Pet.id == pet_id, models.Pet.member_id == member.id).first()
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")

    plan = (
        db.query(models.Plan)
        .filter(models.Plan.id == payload.plan_id, models.Plan.is_active == True)
        .first()
    )
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found or inactive")

    if get_payments_enabled(db):
        raise HTTPException(
            status_code=402,
            detail="Payment is required. Use POST /payments/checkout with pet_id to start checkout.",
        )

    # Same upgrade/renewal gate as the paid checkout — the payments-disabled
    # path must not become a side door around the eligibility rules.
    allowed, code = plan_term_utils.purchase_eligibility(db, pet, plan)
    if not allowed:
        raise HTTPException(
            status_code=409, detail=plan_term_utils.eligibility_message(code)
        )

    grant_plan_to_pet(db, pet, plan, member)
    db.commit()
    db.refresh(pet)
    return pet

