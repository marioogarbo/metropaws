# MetroPaws Backend

FastAPI backend for the MetroPaws Wellness Club — handles membership, pet records, vaccination cards, QR-based service logging, and admin operations.

---

## Stack

| Layer | Tech |
|---|---|
| Framework | FastAPI 0.115+ |
| Database | PostgreSQL (Supabase) via SQLAlchemy 2 |
| Auth | JWT (python-jose) + bcrypt |
| File uploads | multipart/form-data → local `uploads/` |
| Email | SMTP (Gmail) for password resets |
| Python | 3.13 |

---

## Project Structure

```
backend/
├── main.py                 # App entry point, middleware, router registration
├── config.py               # Environment selection (APP_ENV) & settings access
├── database.py             # SQLAlchemy engine, session, get_db dependency
├── auth.py                 # JWT encode/decode + the three access guards
├── models.py               # ORM table definitions
├── paymongo.py             # PayMongo REST client
├── storage.py              # The one upload path (Supabase Storage, local fallback)
├── datetime_utils.py       # Timezone guard shared by the money paths
├── plan_utils.py           # Granting a plan's benefits
├── plan_term_utils.py      # Plan term, upgrade/renewal eligibility
├── pricing_utils.py        # Pack Discount
├── reimbursement_utils.py  # Wallet pools and usage
├── paw_points_utils.py     # Points earning
├── directory_taxonomy.py   # Directory service vocabulary
├── routers/                # HTTP layer; admin/ is a package, one module per subject
├── schemas/                # Pydantic request/response models, one per subject
├── email_utils/            # Outbound email: transport, layout, one per template
├── invoice_utils/          # Receipt PDF: business, formatting, render, delivery
├── scripts/                # One-off CLI, not part of the app lifecycle
├── tests/
├── assets/                 # Logo + bundled Montserrat weights for the PDF
└── uploads/                # Local upload fallback (NOT durable on Render)
```

Anything under `scripts/` is run deliberately and never imported by the app:

```powershell
python -m scripts.migrate          # schema migrations, idempotent
python -m scripts.seed             # reference data, idempotent
python -m scripts.seed_directory   # pet care directory listings
python -m scripts.notify_app_launch   # one-off broadcast, dry run by default
```

---

## Local Development

### 1. Install dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure environment

Nothing to do — `.env.dev` is already in this directory and is what a local run
uses by default. `APP_ENV` picks the environment:

| `APP_ENV` | File read | Database |
|---|---|---|
| _unset_ / `dev` | `.env.dev` | DEV Supabase project |
| `prod` | `.env.prod` | **LIVE** — only ever set this deliberately |

Every process prints its target on startup, so you can always see which
database you are about to touch:

```
[config] APP_ENV=dev  db=aws-1-....pooler.supabase.com:6543/postgres  config=.env.dev
```

For machine-specific settings, create a `.env.local` (gitignored). It is read
first and beats `.env.dev`, so you can point at your own database or fix
`BASE_URL` without editing a file the Render services also use:

```env
BASE_URL=http://localhost:8000
```

`.env.example` documents every supported variable. See `config.py` for the
loading rules.

### 3. Seed the database

```bash
python -m scripts.seed
```

### 4. Run the server

```powershell
.\run.ps1                     # DEV with auto-reload
.\run.ps1 -Port 8080          # DEV on another port
.\run.ps1 -BindHost 0.0.0.0   # DEV reachable from your phone on the LAN
.\run.ps1 -Env prod           # PROD — asks you to type PROD first
```

`run.ps1` sets `APP_ENV` inside the child process only, so an interrupted run
can never leave your terminal pointed at production. Or run uvicorn directly
from this directory:

```bash
python -m uvicorn main:app --reload --port 8000
```

For a **one-off command against production**, scope the variable to the child
process rather than setting it in your shell:

```powershell
cmd /c "set APP_ENV=prod&& python -m scripts.migrate"
```

> Do not use `$env:APP_ENV='prod'; …; $env:APP_ENV=$null`. Ctrl+C aborts the
> rest of the line, the reset never runs, and every later command in that
> terminal silently targets the live database.

API docs available at `http://localhost:8000/docs`

---

## Tests

```bash
uv pip install --python .venv\Scripts\python.exe -e ".[dev]"   # first time
python -m pytest                                                # run them
python -m pytest --cov=. --cov-report=term-missing              # with coverage
```

The suite is hermetic — `tests/conftest.py` pins `DATABASE_URL` to in-memory
SQLite before any project module is imported, so tests can never reach the dev
or production database, and the whole run takes a few seconds.

`tests/routes_snapshot.json` pins every URL the API exposes. If a change adds or
renames a route on purpose, regenerate it and read the diff before committing:

```bash
python -m tests.generate_routes_snapshot
```

---

## Docker

### Build & push to Docker Hub

```powershell
.\deploy.ps1
```

This builds a `linux/amd64` image, tags it with a timestamp and as `latest`, then pushes both to `marioogarbo/metropaws-backend` on Docker Hub.

### Run the image locally

```powershell
docker run -p 8000:8000 --env-file .env.dev -v ${PWD}/uploads:/app/uploads marioogarbo/metropaws-backend:latest
```

> The `uploads/` directory is mounted as a volume so uploaded files persist across container restarts.

> Env files are excluded from the image (`.dockerignore`). Configuration always
> arrives as real environment variables at runtime — `--env-file` locally,
> Render's env vars in deployment — and those override anything on disk.

---

## Key API Endpoints

| Method | Path | Description |
|---|---|---|
| POST | `/register` | Create member account |
| POST | `/login` | Obtain JWT token |
| POST | `/forgot-password` | Send reset email |
| POST | `/reset-password` | Set new password |
| GET | `/me` | Current user profile |
| GET/PUT | `/members/profile` | Member profile |
| GET/POST | `/pets` | List / create pets |
| PUT/DELETE | `/pets/{id}` | Update / delete pet |
| POST | `/pets/{id}/photo` | Upload pet photo |
| POST | `/pets/{id}/vaccination-card` | Upload vax card |
| GET | `/admin/members` | List all members (admin) |
| POST | `/admin/service-log` | Log a service session (admin) |

Full interactive docs: `http://localhost:8000/docs`
