import { CloudOff, ListPlus, Mail, Phone } from "lucide-react";

const CONTACT_EMAIL = "csr@metropaws.ph";
const CONTACT_PHONE_LABEL = "0920-922-4486";
const CONTACT_PHONE_HREF = "tel:09209224486";

/**
 * Shown when the directory could not be fetched.
 *
 * This page deliberately ships no hardcoded copy of the listings (see
 * `lib/directory.ts`), so a visitor who lands here gets a way to reach a human
 * instead of a stale phone number. Both contacts are real and staffed.
 */
export function DirectoryUnavailable() {
  return (
    <section className="bg-(--color-cream) py-16 md:py-20">
      <div className="max-w-6xl mx-auto px-6">
        <div className="rounded-xl border border-(--color-ink-faint) bg-(--color-surface) px-6 py-14 text-center md:px-10">
          <CloudOff
            size={22}
            className="mx-auto text-(--color-ink-faint)"
            aria-hidden="true"
          />
          <p className="mt-4 text-base font-semibold text-(--color-navy)">
            The directory is not loading right now
          </p>
          <p className="mx-auto mt-3 max-w-[52ch] text-sm text-(--color-ink-muted) leading-relaxed">
            We would rather show you nothing than an out-of-date phone number
            for a clinic. Please try again in a few minutes. If your pet needs
            care today, message us and we will point you to the nearest open
            clinic.
          </p>
          <div className="mt-7 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <a
              href={`mailto:${CONTACT_EMAIL}`}
              className="inline-flex min-h-11 items-center gap-2 rounded-lg bg-(--color-gold) px-5 text-sm font-semibold text-(--color-navy) hover:brightness-105 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-navy) transition-all"
            >
              <Mail size={14} aria-hidden="true" />
              {CONTACT_EMAIL}
            </a>
            <a
              href={CONTACT_PHONE_HREF}
              className="inline-flex min-h-11 items-center gap-2 rounded-lg border border-(--color-navy) px-5 text-sm font-semibold text-(--color-navy) hover:bg-(--color-navy) hover:text-(--color-surface) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors"
            >
              <Phone size={14} aria-hidden="true" />
              {CONTACT_PHONE_LABEL}
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}

/** The backend answered, but nothing is published yet. */
export function DirectoryEmpty() {
  return (
    <section className="bg-(--color-cream) py-16 md:py-20">
      <div className="max-w-6xl mx-auto px-6">
        <div className="rounded-xl border border-(--color-ink-faint) bg-(--color-surface) px-6 py-14 text-center md:px-10">
          <ListPlus
            size={22}
            className="mx-auto text-(--color-ink-faint)"
            aria-hidden="true"
          />
          <p className="mt-4 text-base font-semibold text-(--color-navy)">
            No listings published yet
          </p>
          <p className="mx-auto mt-3 max-w-[52ch] text-sm text-(--color-ink-muted) leading-relaxed">
            We are still putting this list together. If there is a vet or
            groomer you trust, send us the name and we will look into adding
            them.
          </p>
          <a
            href={`mailto:${CONTACT_EMAIL}?subject=Directory%20suggestion`}
            className="mt-7 inline-flex min-h-11 items-center gap-2 rounded-lg bg-(--color-gold) px-5 text-sm font-semibold text-(--color-navy) hover:brightness-105 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-navy) transition-all"
          >
            <Mail size={14} aria-hidden="true" />
            Suggest a place
          </a>
        </div>
      </div>
    </section>
  );
}

/**
 * Closing note.
 *
 * The removal line matters: these businesses did not ask to be listed, so a
 * one-line, obvious way to be corrected or taken down is what turns a complaint
 * into a two-minute admin edit.
 */
export function DirectoryNote() {
  return (
    <section className="bg-(--color-cream-warm) border-t border-(--color-ink-faint)/50 py-14 md:py-16">
      <div className="max-w-6xl mx-auto px-6">
        <div className="grid gap-8 md:grid-cols-2 md:gap-14">
          <div>
            <h2 className="text-xl font-bold text-(--color-navy) tracking-tight">
              Know somewhere we should add?
            </h2>
            <p className="mt-3 text-sm text-(--color-ink-muted) leading-relaxed max-w-[54ch]">
              Send the business name and how to reach them. We check the details
              ourselves before anything goes on this page.
            </p>
            <a
              href={`mailto:${CONTACT_EMAIL}?subject=Directory%20suggestion`}
              className="mt-5 inline-flex min-h-11 items-center gap-2 rounded-lg bg-(--color-navy) px-5 text-sm font-semibold text-(--color-gold) hover:bg-(--color-navy-mid) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors"
            >
              <Mail size={14} aria-hidden="true" />
              Suggest a place
            </a>
          </div>

          <div className="md:border-l md:border-(--color-ink-faint)/50 md:pl-14">
            <h2 className="text-xl font-bold text-(--color-navy) tracking-tight">
              Is this your business?
            </h2>
            <p className="mt-3 text-sm text-(--color-ink-muted) leading-relaxed max-w-[54ch]">
              Listings are compiled from publicly posted contact details. If
              something is wrong, or you would rather not be listed, email{" "}
              <a
                href={`mailto:${CONTACT_EMAIL}?subject=Directory%20listing%20correction`}
                className="font-medium text-(--color-navy) underline underline-offset-4 hover:text-(--color-ink) transition-colors"
              >
                {CONTACT_EMAIL}
              </a>{" "}
              and we will correct or remove it.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
