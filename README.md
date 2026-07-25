# MetroPaws

Monorepo for MetroPaws — a Filipino pet-wellness membership club. Three
independent projects, each with its own toolchain, in one repository.

```
metropaws/
├── backend/    FastAPI (Python)      → Render (dev + prod), Root Directory = backend
├── website/    Next.js 15 (TypeScript) → Vercel, Root Directory = website
└── mobile/     Flutter (Dart)         → Android APK / Play Store AAB, built locally
```

This is a plain polyglot monorepo — no Turborepo/Nx/workspaces. Each project
builds, tests, and deploys on its own; grouping them here just makes changes
across all three easy to see in one place.

## Projects

### backend/ — API
FastAPI + SQLAlchemy + PostgreSQL (Supabase). Auth (JWT), members/pets,
reimbursements + Benefit Wallet, PayMongo payments, transactional email
(ZeptoMail). Deployed as a Docker image to Render.

```bash
cd backend
python -m venv .venv && .venv/Scripts/activate    # Windows
pip install -r requirements.txt
uvicorn main:app --reload
```

### website/ — Marketing site + Admin portal
Next.js 15 (App Router) + Tailwind v4. Public marketing pages, member
auth/reset flows, and the staff admin dashboard. Deployed to Vercel.

```bash
cd website
npm install
npm run dev
```

### mobile/ — Member app
Flutter (member dashboard, digital ID, reimbursements, PawPoints). Built to a
signed APK / Play Store AAB locally.

```bash
cd mobile
flutter pub get
flutter run
flutter build apk --release --dart-define=ENV=prod    # release build
```

## Secrets

All secrets live in **gitignored** files, never in the repo:
- `backend/.env`, `backend/.env.prod`, `backend/.env.dev`
- `mobile/android/key.properties` (release-signing passwords)

See each project's `CLAUDE.md` for the full environment-variable reference and
architecture notes.
