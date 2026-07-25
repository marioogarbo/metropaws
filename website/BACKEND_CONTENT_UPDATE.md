# Backend content to update (Plans & FAQs)

The home page renders **Plans** and **FAQs** from the live backend
(`/plans`, `/faqs`). The in-repo arrays are only fallbacks used when the backend
is unreachable. The verification run confirmed the live DB still holds the **old**
copy (old plan taglines, old "session tracker" / "Digital Pawprint" FAQ text).

Apply the changes below via **Admin → Plans** and **Admin → FAQs** (or directly in
the database). After saving, the home page picks them up within the 1-hour
revalidation window.

---

## Plans

Update each plan's **tagline** and **features** to the outcome-first, non-insurance
wording from the Member Manual. Prices are unchanged.

### Standard — ₱2,999 / yr (₱300 mo)
- **Tagline:** `Smart Pet Parenting Starts Here`
- **Features:**
  - Professional veterinary care — up to 2 consultations a year
  - Annual vaccines with deworming and kennel cough
  - Grooming privileges — up to 15% member savings
  - Laboratory savings — up to 10% member savings
  - Emergency assistance — 10% off the initial gate fee, once a year
  - Digital Pet Passport, reminders & PawPoints rewards

### Deluxe — ₱5,999 / yr (₱600 mo) — *featured*
- **Tagline:** `The Complete Preventive Care Membership`
- **Features:**
  - Enhanced veterinary support — up to 4 consultations a year
  - Annual vaccines with deworming and kennel cough
  - One emergency case a year — gate fee plus basic stabilization
  - Laboratory savings — up to 10% member savings
  - Complimentary grooming — 2 sessions a year
  - Enhanced PawPoints & priority member processing

### Premium — ₱10,999 / yr (₱1,200 mo)
- **Tagline:** `The Premier Pet Parenting Membership`
- **Features:**
  - Unlimited veterinary consultations (per program terms)
  - Premium grooming — 4 complimentary sessions a year
  - Annual diagnostic screening — includes CBC blood test
  - Emergency Bridge — first ₱5,000 covered, plus 10% on bills up to ₱15,000
  - Digital Pet Passport Premium, Elite PawPoints & concierge support

---

## FAQs

Replace the current FAQ rows with this set (matches the repo fallback). Removes the
inaccurate "fees arranged at your partner clinic" answer, drops the "session"
framing, and adds claims + PawPoints questions.

1. **Is MetroPaws free?**
   Creating an account and registering your pet is completely free. Paid annual
   plans (Standard, Deluxe, Premium) unlock wellness benefits, and you only pay
   when you activate one. MetroPaws is a membership club, not insurance or an HMO.

2. **How do claims and reimbursements work?**
   Visit any clinic or groomer, pay them directly, then upload your receipt in the
   app. We check it against your plan and benefit balance, and approved wellness
   benefits are reimbursed to your Benefit Wallet.

3. **Do I have to switch to a partner clinic?**
   No. Use the vet your pet already trusts. MetroPaws partners across Las Piñas
   offer extra member perks, but you are never required to switch providers to
   claim your benefits.

4. **What are PawPoints?**
   PawPoints are loyalty points that reward responsible pet ownership. Earn them by
   joining, renewing, referring friends, completing approved claims, and attending
   events, then redeem for badges, pet ID tags, wellness-credit boosters, and more.

5. **Can I manage multiple pets?**
   Yes. Add every pet in your household — dogs, cats, or both. Each pet gets its own
   Digital Pet Passport with profile, vaccination, grooming, and consultation
   records, all under one account.

6. **Does my QR Pet ID work without internet?**
   Yes. Your QR Pet ID is cached on your phone, so you can show it at the clinic even
   on a weak signal. You only need a connection to sync new records or submit a claim.

---

## Note on PawPoints numbers (for future reference)

The home page PawPoints section uses the **Framework Rev1** values (newer than the
Member Manual Rev0). If you later build a PawPoints admin/earn config, use Rev1:
activation 100/200/400 (Std/Dlx/Prm), renewal 150/300/600, referral 100/200/350,
approved vet claim 20/40/60, pet birthday 20/30/50.
