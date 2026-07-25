# MetroPaws Monorepo Migration — Stage 2 Plan

**Status:** Stage 1 complete (mobile + website under version control). Stage 2 not yet executed — awaiting your review + decisions below.

**Goal:** One git repo at the `metropaws/` root containing all three projects, each keeping its own toolchain and deploying independently. This is a *plain polyglot monorepo* — **no** Turborepo/Nx/workspaces (they give zero benefit across Python + Dart + TypeScript).

```
metropaws/                 ← ONE git repo (github.com/marioogarbo/metropaws)
├── .gitignore             ← root-level, aggregates the three
├── README.md
├── backend/    FastAPI    → Render (dev + prod), Root Directory = backend
├── mobile/     Flutter    → built to APK manually (no CI change)
└── website/    Next.js    → Vercel, Root Directory = website
```

---

## What Stage 1 already did

- `mobile/` — `git init` + first commit (was previously **unversioned** — this is why deleting the folder lost work).
- `website/` — committed a large body of never-committed work (`lib/api.ts`, member/reset/forgot-password pages, admin providers, etc.) on `master`.
- Neither has been **pushed** yet — `gh` is not logged in.

### Do these now (interactive terminal — I can't, gh isn't authed)

```bash
# 1. Authenticate GitHub CLI
gh auth login

# 2. Create + push the mobile remote (private)
cd C:/Users/mario/Desktop/metropaws/mobile
gh repo create marioogarbo/metropaws-mobile --private --source=. --remote=origin --push

# 3. Push the salvaged website work
cd C:/Users/mario/Desktop/metropaws/website
git push origin master
```

> After this, all three projects exist safely on GitHub as separate repos. Stage 2 then merges them — but even if you stop here, nothing is at risk anymore.

---

## Decisions needed before Stage 2 executes

1. **New repo name** — recommend `metropaws` (private). The old repos become read-only archives.
2. **Branch convention** — pick ONE mainline. Recommend **`main`**.
   - backend default = `main`, but latest work is on `fix/payment-activation-resilience`. → Decide: merge that feature branch into `main` first, *or* bring the feature-branch tip in as the monorepo mainline.
   - website default = `master`. → Its tip becomes `website/` in the monorepo.
3. **Preserve history?** — Recommend **yes** (subtree merge keeps every commit). Alternative: fresh start (simpler, throws away all history — not recommended).
4. **CI/CD** — confirm current hosts: backend = Render (dev + prod services), website = Vercel. (Mobile has no CI.)

---

## Stage 2 steps (history-preserving, done in a COPY for safety)

> Executed against a fresh copy so the working setup is never destroyed until verified.

### A. Safety net
1. Confirm backend, website, mobile are all pushed to GitHub (above).
2. Work in a scratch copy: `metropaws-mono/` — verify there, then swap.

### B. Build the monorepo (git surgery — I can do this)
For each subproject, merge its full history under a subdirectory prefix (classic recipe):

```bash
cd metropaws-mono           # fresh dir
git init
git commit --allow-empty -m "chore: initialize MetroPaws monorepo"

# backend  (choose the branch decided in Decision 2)
git remote add _backend ../backend
git fetch _backend
git merge -s ours --no-commit --allow-unrelated-histories _backend/main
git read-tree --prefix=backend/ -u _backend/main
git commit -m "merge backend/ into monorepo (history preserved)"
git remote remove _backend

# website
git remote add _website ../website
git fetch _website
git merge -s ours --no-commit --allow-unrelated-histories _website/master
git read-tree --prefix=website/ -u _website/master
git commit -m "merge website/ into monorepo (history preserved)"
git remote remove _website

# mobile (single commit, same recipe)
git remote add _mobile ../mobile
git fetch _mobile
git merge -s ours --no-commit --allow-unrelated-histories _mobile/master
git read-tree --prefix=mobile/ -u _mobile/master
git commit -m "merge mobile/ into monorepo (history preserved)"
git remote remove _mobile
```

### C. Root scaffolding
- Root `.gitignore` (aggregates node_modules, .next, .venv, __pycache__, build/, .dart_tool/, .env*, etc.).
- Root `README.md` documenting the three projects and how to run each.
- Verify no nested `.git` dirs remain (the merge brings files, not `.git`).

### D. Publish
```bash
gh repo create marioogarbo/metropaws --private --source=. --remote=origin --push
```

### E. Re-point CI/CD (your manual dashboard work — I cannot access these)
- **Render (backend, both dev + prod services):** Settings → connect to new `metropaws` repo → set **Root Directory = `backend`** → set the deploy branch. Render only rebuilds on changes under `backend/`.
- **Vercel (website):** Project Settings → Git → connect `metropaws` repo → set **Root Directory = `website`**. Add an **Ignored Build Step** (`git diff --quiet HEAD^ HEAD -- .`) so it skips builds when `website/` didn't change.
- **Mobile:** nothing — continue building the APK locally.

### F. Verify
- Push a trivial change under `backend/` → confirm only Render redeploys.
- Push a trivial change under `website/` → confirm only Vercel redeploys.
- Confirm both deploys succeed and the live sites/API work.

### G. Cleanup (only after F passes)
- Archive old repos on GitHub (`metropaws-backend`, `metropaws-website`) → mark read-only / rename with `-archived` suffix.
- Delete stray branches (`website`'s `worktree-agent-*`, unused `main`/`staging` if consolidating).
- Replace the three `metropaws/*` folders with the verified monorepo copy.

---

## Risk assessment

| Risk | Mitigation |
|------|------------|
| Breaking live deploys | Old repos stay intact until Step G; CI re-point is reversible |
| Losing history | Subtree merge preserves it; verify `git log -- backend/` after merge |
| Committing secrets | `.env*` already ignored in all three; audited during Stage 1 |
| Nested `.git` confusion | Merge copies files only; verify no `backend/.git` etc. remain |
| Mobile build bloat | `.gitignore` already excludes `build/` + `.dart_tool/` (~78 MB) |

**Highest-risk step is E (CI/CD).** It's manual and on your side. Everything before it is reversible.
