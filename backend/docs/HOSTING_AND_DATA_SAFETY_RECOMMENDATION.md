# MetroPaws — Hosting & Data Safety Recommendation

> **For:** MetroPaws management
> **From:** Development team
> **Date:** 27 June 2026
> **In one line:** The app is currently running entirely on **free hosting tiers**. That's fine for testing, but **before we launch the new receipt-reimbursement feature and onboard real members, we need to move the live app off free tiers and add proper file storage.** The cost is small — about **₱1,800/month (~US$32)** — and it does not require changing providers.

---

## The situation, in plain terms

The MetroPaws app is built in three parts: the **mobile app**, the **admin website**, and the **server + database** behind them. Today the server, database, and file uploads all run on **free plans**. Free plans come with three limitations that matter now that we're about to handle members' **money and official receipts**:

1. **Uploaded files are not safely stored.**
   Right now, when a member uploads a pet photo or vaccination card, the file is kept in temporary space that **gets wiped every time the server updates or goes idle.** In practice this means some uploaded files are already being lost. Receipts for reimbursement are financial records — we cannot risk losing them.

2. **The app "goes to sleep."**
   On the free plan, the server shuts down after about 15 minutes of no activity. The next member who opens the app waits 30–60 seconds for it to wake up — it looks broken or dead. Not acceptable for a paying member.

3. **The database can pause, and backups are minimal.**
   The free database pauses after about a week of inactivity and keeps only very limited backups. For real member data and financial claims, we need guaranteed uptime and **daily backups**.

---

## What we recommend

Stay with the **same providers** (Render for the server, Supabase for the database) — they are solid, professional services used by real businesses. We simply need to move the **live** app off the free tiers and turn on proper file storage.

| Area | Today (free) | Recommended | Approx. cost/month | What it fixes |
|---|---|---|---|---|
| **File storage** | Temporary — files can be lost | **Supabase Storage** (proper file storage) | Free to start, cheap as it grows | Photos, vaccination cards, and receipts are kept safely and permanently |
| **Server** | Free — sleeps & wipes files | **Render paid (Starter)** | ~US$7 (~₱400) | App is always on; no 30–60s "dead app" wait; no data loss on updates |
| **Database** | Free — pauses, thin backups | **Supabase Pro** | ~US$25 (~₱1,400) | No pausing, **daily backups**, room to grow |

**Total: roughly US$32 / ₱1,800 per month** for a genuinely safe, production-ready setup.
*(Prices are approximate and worth confirming at sign-up.)*

---

## What we are **not** recommending — and why

We considered moving to a large cloud provider (e.g., **Google Cloud / AWS**). **We do not recommend that right now.** It would cost more, take longer, and add ongoing technical overhead — without making the app any safer than the simple plan above. Those platforms make sense much later, *if* MetroPaws grows to thousands of active members or faces formal compliance audits. For where the business is today, it would be paying for complexity we don't need.

**The honest summary:** "Is our data safe?" is really a question about *durable file storage + database backups + keeping the app awake.* All three are solved by the ~₱1,800/month plan above. Changing cloud providers is not necessary.

---

## Suggested timing (so costs come in steps, not all at once)

1. **Before the reimbursement feature launches:** turn on proper **file storage** (free to start) and upgrade the **server** to the paid Starter plan (~₱400/mo). This removes the "lost files" and "sleeping app" problems immediately.
2. **Before we onboard paying members and handle live financial claims:** upgrade the **database** to Pro (~₱1,400/mo) for daily backups and no pausing.
3. **Much later, only if we outgrow this:** revisit bigger infrastructure.

---

## Bottom line

The current free setup is fine for a demo, but **not safe for handling members' financial receipts and real data.** The fix is inexpensive (~₱1,800/month), keeps our current providers, and can be rolled out in two small steps. We recommend approving steps 1 and 2 above before the reimbursement feature goes live.
