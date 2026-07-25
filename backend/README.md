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

Copy the example below into a `.env` file in this directory:

```env
DATABASE_URL=postgresql://user:password@host:5432/dbname
SECRET_KEY=your-secret-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080

UPLOAD_DIR=uploads
BASE_URL=http://localhost:8000
FRONTEND_URL=http://localhost:3000

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your@gmail.com
SMTP_PASSWORD=your-app-password
EMAIL_FROM=your@gmail.com
```

### 3. Seed the database

```bash
python seed.py
```

### 4. Run the server

```bash
uvicorn main:app --reload --port 8000
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
docker run -p 8000:8000 --env-file .env -v ${PWD}/uploads:/app/uploads marioogarbo/metropaws-backend:latest
```

> The `uploads/` directory is mounted as a volume so uploaded files persist across container restarts.

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
