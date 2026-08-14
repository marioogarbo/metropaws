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
├── main.py           # App entry point, router registration
├── config.py         # Environment selection & settings access
├── auth.py           # JWT creation & password hashing
├── database.py       # SQLAlchemy engine & session
├── models.py         # ORM table definitions
├── schemas.py        # Pydantic request/response models
├── email_utils.py    # Password reset email sender
├── seed.py           # Seeds service types + default admin
├── routers/
│   ├── auth.py       # /register, /login, /forgot-password, /reset-password, /me
│   ├── members.py    # Member profile & QR token
│   ├── pets.py       # Pet CRUD, photo & vax card uploads
│   └── admin.py      # Service types, session logging
└── uploads/          # Uploaded files (vax cards, pet photos)
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
python seed.py
```

### 4. Run the server

```bash
uvicorn main:app --reload --port 8000
```

To point a one-off command at production, set `APP_ENV` for that command only —
never as a persistent shell or machine variable:

```powershell
$env:APP_ENV='prod'; python migrate.py; $env:APP_ENV=$null
```

API docs available at `http://localhost:8000/docs`

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
