"""Idempotent schema migrations, applied in order.

Every step is safe to re-run: columns use ``ADD COLUMN IF NOT EXISTS``, indexes
and constraints are guarded, and the data fixes only touch rows still in the
old shape. Running the whole file against an up-to-date database is a no-op.

Nothing happens on import — run it explicitly, and mind which database
``APP_ENV`` resolves to:

    python migrate.py                          # dev, the default
    cmd /c "set APP_ENV=prod&& python migrate.py"

``deploy.ps1`` does NOT run this. A deploy that needs a new column has to be
migrated first, or every query touching that table fails.
"""
import config
import models
from database import engine
from sqlalchemy import text


def create_new_tables() -> None:
    """Create tables that don't exist yet. Never alters an existing one."""
    models.Base.metadata.create_all(bind=engine)


def add_pet_core_columns() -> None:
    """Bring the original `pets` table up to the current model: species, owner,
    breed, weight, photos, sex, notes and a creation timestamp."""
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE pets
                ADD COLUMN IF NOT EXISTS species VARCHAR,
                ADD COLUMN IF NOT EXISTS member_id VARCHAR REFERENCES members(id),
                ADD COLUMN IF NOT EXISTS breed VARCHAR,
                ADD COLUMN IF NOT EXISTS weight_kg FLOAT,
                ADD COLUMN IF NOT EXISTS photo_url VARCHAR,
                ADD COLUMN IF NOT EXISTS vax_card_url VARCHAR,
                ADD COLUMN IF NOT EXISTS sex VARCHAR,
                ADD COLUMN IF NOT EXISTS notes TEXT,
                ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now()
        """))
        conn.commit()


def replace_pet_age_with_birth_date() -> None:
    """Replace age_years with birth date fields."""
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE pets
                ADD COLUMN IF NOT EXISTS birth_month INTEGER,
                ADD COLUMN IF NOT EXISTS birth_year INTEGER,
                ADD COLUMN IF NOT EXISTS birth_day INTEGER
        """))
        conn.commit()

        # Populate birth_month/birth_year from age_years where available (best-effort)
        conn.execute(text("""
            UPDATE pets
            SET
                birth_year = CASE
                    WHEN birth_year IS NULL AND pg_catalog.pg_typeof(NULL) IS NOT NULL THEN
                        EXTRACT(YEAR FROM NOW())::integer
                    ELSE birth_year
                END,
                birth_month = COALESCE(birth_month, 1)
            WHERE birth_year IS NULL
        """))
        conn.execute(text("""
            UPDATE pets
            SET
                birth_year = EXTRACT(YEAR FROM NOW())::integer,
                birth_month = 1
            WHERE birth_year IS NULL
        """))
        conn.commit()

        # Default breed/weight for any existing NULL rows
        conn.execute(text("UPDATE pets SET breed = 'Unknown' WHERE breed IS NULL"))
        conn.execute(text("UPDATE pets SET weight_kg = 0 WHERE weight_kg IS NULL"))
        conn.commit()

        # Set NOT NULL constraints now that all rows are populated
        conn.execute(text("""
            ALTER TABLE pets
                ALTER COLUMN birth_month SET NOT NULL,
                ALTER COLUMN birth_year SET NOT NULL,
                ALTER COLUMN breed SET NOT NULL,
                ALTER COLUMN weight_kg SET NOT NULL
        """))
        conn.commit()

        # Drop the old age_years column
        conn.execute(text("ALTER TABLE pets DROP COLUMN IF EXISTS age_years"))
        conn.commit()


def add_member_plan_and_booking_columns() -> None:
    """Plan_id on members + credit_used/clinic_id on bookings + plan_services
    table.
    """
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE members
                ADD COLUMN IF NOT EXISTS plan_id VARCHAR REFERENCES plans(id)
        """))
        conn.execute(text("""
            ALTER TABLE bookings
                ADD COLUMN IF NOT EXISTS credit_used BOOLEAN NOT NULL DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS clinic_id VARCHAR REFERENCES clinic_partners(id)
        """))
        conn.commit()


def add_clinic_user_role() -> None:
    """Add 'clinic' to userrole enum if not already present."""
    with engine.connect() as conn:
        conn.execute(text("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_enum
                    WHERE enumlabel = 'clinic'
                    AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'userrole')
                ) THEN
                    ALTER TYPE userrole ADD VALUE 'clinic';
                END IF;
            END
            $$;
        """))
        conn.commit()


def deduplicate_pet_services() -> None:
    """Consolidate duplicate pet_services rows and add unique constraint. Root
    cause: autoflush=False session + founding-bonus loop creating second
    rows when the plan loop's db.add() hadn't been flushed yet.
    """
    with engine.connect() as conn:
        # Step 1: merge duplicates — keep the row with the lowest id, sum sessions.
        conn.execute(text("""
            UPDATE pet_services AS ps
            SET
                total_sessions = agg.total_sum,
                used_sessions   = agg.used_sum
            FROM (
                SELECT
                    MIN(id)                  AS keep_id,
                    pet_id,
                    service_type_id,
                    SUM(total_sessions)      AS total_sum,
                    SUM(used_sessions)       AS used_sum
                FROM pet_services
                GROUP BY pet_id, service_type_id
                HAVING COUNT(*) > 1
            ) AS agg
            WHERE ps.id = agg.keep_id
        """))
        conn.commit()

        # Step 2: delete the extra rows (rn > 1 per group).
        conn.execute(text("""
            DELETE FROM pet_services
            WHERE id IN (
                SELECT id FROM (
                    SELECT
                        id,
                        ROW_NUMBER() OVER (
                            PARTITION BY pet_id, service_type_id
                            ORDER BY id
                        ) AS rn
                    FROM pet_services
                ) ranked
                WHERE rn > 1
            )
        """))
        conn.commit()

        # Step 3: add the unique constraint (idempotent — skips if already present).
        conn.execute(text("""
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint
                    WHERE conname = 'uq_pet_service'
                ) THEN
                    ALTER TABLE pet_services
                        ADD CONSTRAINT uq_pet_service UNIQUE (pet_id, service_type_id);
                END IF;
            END
            $$;
        """))
        conn.commit()


def add_reimbursement_cap_to_plan_services() -> None:
    """Reimbursement feature. New tables (reimbursements, reimbursement_events)
    are created by the create_all() call at the top of this file.
    Existing-table columns are not, so add the per-plan/category
    reimbursement cap here (idempotent).
    """
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE plan_services
                ADD COLUMN IF NOT EXISTS reimbursement_cap_centavos INTEGER NOT NULL DEFAULT 0
        """))
        conn.commit()


def add_member_payout_details() -> None:
    """Member payout details (where approved reimbursements are sent)."""
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE members
                ADD COLUMN IF NOT EXISTS payout_method VARCHAR,
                ADD COLUMN IF NOT EXISTS payout_account_name VARCHAR,
                ADD COLUMN IF NOT EXISTS payout_account_number VARCHAR,
                ADD COLUMN IF NOT EXISTS payout_bank_name VARCHAR
        """))
        conn.commit()


def add_receipt_hash_and_payout_reference() -> None:
    """Reimbursement hardening — duplicate-receipt hash + payout reference."""
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE reimbursements
                ADD COLUMN IF NOT EXISTS receipt_sha256 VARCHAR,
                ADD COLUMN IF NOT EXISTS paid_reference VARCHAR
        """))
        conn.commit()


def add_agreement_acceptance() -> None:
    """Digital Agreement acceptance captured at registration."""
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE members
                ADD COLUMN IF NOT EXISTS agreement_accepted_at TIMESTAMPTZ,
                ADD COLUMN IF NOT EXISTS agreement_version VARCHAR
        """))
        conn.commit()


def add_pet_identity_photos() -> None:
    """Pet identity photos (MP-FRM-PET-001). photo_url (existing column) is
    slot 1 (front face); these 7 cover the remaining slots.
    """
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE pets
                ADD COLUMN IF NOT EXISTS photo_full_body_url VARCHAR,
                ADD COLUMN IF NOT EXISTS photo_with_owner_url VARCHAR,
                ADD COLUMN IF NOT EXISTS photo_left_profile_url VARCHAR,
                ADD COLUMN IF NOT EXISTS photo_right_profile_url VARCHAR,
                ADD COLUMN IF NOT EXISTS photo_rear_url VARCHAR,
                ADD COLUMN IF NOT EXISTS photo_top_url VARCHAR,
                ADD COLUMN IF NOT EXISTS photo_with_id_card_url VARCHAR
        """))
        conn.commit()


def add_member_photo() -> None:
    """Member profile photo (Account tab avatar)."""
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE members
                ADD COLUMN IF NOT EXISTS photo_url VARCHAR
        """))
        conn.commit()


def deduplicate_plan_services() -> None:
    """Enforce one plan_services row per (plan, service_type). Admins can now
    add a category to an existing plan (Emergency → Deluxe), so guard
    against dupes.
    """
    with engine.connect() as conn:
        # Merge any pre-existing duplicates first (keep lowest id, max cap + sessions).
        conn.execute(text("""
            UPDATE plan_services AS ps
            SET
                sessions = agg.max_sessions,
                reimbursement_cap_centavos = agg.max_cap
            FROM (
                SELECT
                    MIN(id)                            AS keep_id,
                    plan_id,
                    service_type_id,
                    MAX(sessions)                      AS max_sessions,
                    MAX(reimbursement_cap_centavos)    AS max_cap
                FROM plan_services
                GROUP BY plan_id, service_type_id
                HAVING COUNT(*) > 1
            ) AS agg
            WHERE ps.id = agg.keep_id
        """))
        conn.execute(text("""
            DELETE FROM plan_services
            WHERE id IN (
                SELECT id FROM (
                    SELECT
                        id,
                        ROW_NUMBER() OVER (
                            PARTITION BY plan_id, service_type_id
                            ORDER BY id
                        ) AS rn
                    FROM plan_services
                ) ranked
                WHERE rn > 1
            )
        """))
        conn.commit()

        conn.execute(text("""
            CREATE UNIQUE INDEX IF NOT EXISTS uq_plan_service
                ON plan_services (plan_id, service_type_id)
        """))
        conn.commit()


def add_benefit_wallet_pools() -> None:
    """TWO Benefit Wallet pools per plan (client decision 2026-07-16) —
    Preventive Wellness (reimbursement_wallet_centavos) and Emergency
    (emergency_wallet_centavos). Backfill each pool from the matching legacy
    per-category cap: the "Preventive Wellness" category cap seeds the
    preventive pool, the "Emergency" category cap seeds the emergency pool.
    Only fills pools still at 0 so we never clobber values an admin has set.
    ⚠️ A DB that has no "Preventive Wellness"/"Emergency" plan_services rows
    (e.g. the dev DB, whose only reimbursable caps are
    Consultation/Vaccines) gets nothing from this backfill — set those
    plans' pools via the website admin Plans editor after deploy.
    """
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE plans
                ADD COLUMN IF NOT EXISTS reimbursement_wallet_centavos INTEGER NOT NULL DEFAULT 0
        """))
        conn.execute(text("""
            ALTER TABLE plans
                ADD COLUMN IF NOT EXISTS emergency_wallet_centavos INTEGER NOT NULL DEFAULT 0
        """))
        # Preventive pool ← "Preventive Wellness" category cap.
        prev_res = conn.execute(text("""
            UPDATE plans
            SET reimbursement_wallet_centavos = sub.cap
            FROM (
                SELECT ps.plan_id, MAX(ps.reimbursement_cap_centavos) AS cap
                FROM plan_services ps
                JOIN service_types st ON st.id = ps.service_type_id
                WHERE lower(st.name) = 'preventive wellness'
                GROUP BY ps.plan_id
            ) AS sub
            WHERE plans.id = sub.plan_id
              AND plans.reimbursement_wallet_centavos = 0
              AND sub.cap > 0
        """))
        # Emergency pool ← "Emergency" category cap.
        emg_res = conn.execute(text("""
            UPDATE plans
            SET emergency_wallet_centavos = sub.cap
            FROM (
                SELECT ps.plan_id, MAX(ps.reimbursement_cap_centavos) AS cap
                FROM plan_services ps
                JOIN service_types st ON st.id = ps.service_type_id
                WHERE lower(st.name) = 'emergency'
                GROUP BY ps.plan_id
            ) AS sub
            WHERE plans.id = sub.plan_id
              AND plans.emergency_wallet_centavos = 0
              AND sub.cap > 0
        """))
        conn.commit()
        print(
            f"Wallet backfill: preventive set on {prev_res.rowcount} plan(s), "
            f"emergency set on {emg_res.rowcount} plan(s). "
            "Plans with no matching legacy caps must be set via the admin Plans editor."
        )


def add_direct_provider_payouts() -> None:
    """Direct-to-provider reimbursement payouts (client decision, see
    routers/reimbursements.py). New table `reimbursement_providers` is
    created by the create_all() call at the top of this file.
    `payout_target` is a new Postgres enum type on an EXISTING table, so it
    needs an explicit CREATE TYPE (idempotent) before the ALTER.
    """
    with engine.connect() as conn:
        conn.execute(text("""
            DO $$
            BEGIN
                CREATE TYPE payouttarget AS ENUM ('member', 'provider');
            EXCEPTION
                WHEN duplicate_object THEN NULL;
            END
            $$;
        """))
        conn.commit()
        conn.execute(text("""
            ALTER TABLE reimbursements
                ADD COLUMN IF NOT EXISTS payout_target payouttarget NOT NULL DEFAULT 'member',
                ADD COLUMN IF NOT EXISTS provider_id VARCHAR REFERENCES reimbursement_providers(id)
        """))
        conn.commit()


def add_pack_discount_column() -> None:
    """Pack Discount audit trail (2026-07-27). payments.discount_php records
    the multi-pet discount applied at checkout (whole pesos, 0 = none);
    amount_php stays the FINAL charged amount. Existing table, so create_all
    won't add it — explicit ALTER required on each deployed DB (dev + prod).
    """
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE payments
                ADD COLUMN IF NOT EXISTS discount_php INTEGER NOT NULL DEFAULT 0
        """))
        conn.commit()


def add_per_member_direct_pay_override() -> None:
    """Per-member direct-pay override (2026-08-13). The global
    direct_provider_payment_enabled switch was all-or-nothing — one member
    abusing the flow meant turning it off for everyone. These columns let an
    admin restrict a single member (Agreement §5.7 "Authorization
    Restricted", grounds in §17) while the feature stays on for the rest.
    NULL = follow the global switch, so every existing row keeps today's
    behaviour with no backfill.
    """
    with engine.connect() as conn:
        conn.execute(text("""
            ALTER TABLE members
                ADD COLUMN IF NOT EXISTS direct_pay_enabled BOOLEAN,
                ADD COLUMN IF NOT EXISTS direct_pay_note TEXT,
                ADD COLUMN IF NOT EXISTS direct_pay_updated_by_admin_id VARCHAR REFERENCES users(id),
                ADD COLUMN IF NOT EXISTS direct_pay_updated_at TIMESTAMPTZ
        """))
        conn.commit()


# Order matters: later steps assume the columns earlier ones added.
MIGRATIONS = (
    create_new_tables,
    add_pet_core_columns,
    replace_pet_age_with_birth_date,
    add_member_plan_and_booking_columns,
    add_clinic_user_role,
    deduplicate_pet_services,
    add_reimbursement_cap_to_plan_services,
    add_member_payout_details,
    add_receipt_hash_and_payout_reference,
    add_agreement_acceptance,
    add_pet_identity_photos,
    add_member_photo,
    deduplicate_plan_services,
    add_benefit_wallet_pools,
    add_direct_provider_payouts,
    add_pack_discount_column,
    add_per_member_direct_pay_override,
)


def main() -> None:
    print(f"Migrating {config.database_target()}\n")
    for step in MIGRATIONS:
        print(f"  {step.__name__} ...", end=" ", flush=True)
        step()
        print("done")
    print("\nMigration complete.")


if __name__ == "__main__":
    main()
