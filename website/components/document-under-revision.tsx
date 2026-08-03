import Link from "next/link";
import { FileClock, ArrowLeft } from "lucide-react";

import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { DOCUMENT_REVISION_CONTACT } from "@/lib/legal-documents";

interface DocumentUnderRevisionProps {
  /** Reader-facing name, e.g. "Membership Agreement". */
  documentName: string;
}

/**
 * Stands in for a member document that has been taken down for rewriting.
 *
 * Deliberately says plainly that the document is being updated rather than
 * pretending the page moved: members reach this from links inside the app, and
 * a vague redirect reads as a broken app.
 */
export function DocumentUnderRevision({ documentName }: DocumentUnderRevisionProps) {
  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-1 items-center justify-center bg-(--color-cream) px-6 py-20 sm:py-28">
        <div className="w-full max-w-xl">
          <div className="rounded-2xl border border-(--color-silver-hi) bg-(--color-surface) p-8 sm:p-10">
            <span className="inline-flex items-center gap-2 rounded-full bg-(--gold-light) px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.12em] text-(--gold-dark)">
              <FileClock className="h-3.5 w-3.5" aria-hidden="true" />
              Being updated
            </span>

            <h1 className="mt-5 text-2xl sm:text-3xl font-bold tracking-tight text-(--color-navy)">
              Our {documentName} is being updated
            </h1>

            <p className="mt-4 text-sm leading-relaxed text-(--color-ink)">
              We&apos;re rewriting this document so it reflects how a MetroPaws
              membership actually works today. It has been taken down while that
              work is underway, and the new version will be published on this
              page once it&apos;s ready.
            </p>

            <p className="mt-4 text-sm leading-relaxed text-(--color-ink-muted)">
              Your membership and its benefits are unaffected — nothing about
              what you&apos;ve already paid for changes while we do this.
            </p>

            <div className="mt-7 border-t border-(--color-ink-faint)/40 pt-6">
              <p className="text-sm leading-relaxed text-(--color-ink-muted)">
                Need the terms of your membership in the meantime, or have a
                question? Email{" "}
                <a
                  href={`mailto:${DOCUMENT_REVISION_CONTACT}`}
                  className="font-medium text-(--color-navy) underline underline-offset-2 transition-colors hover:text-(--color-gold)"
                >
                  {DOCUMENT_REVISION_CONTACT}
                </a>{" "}
                and our team will help you directly.
              </p>
              <p className="mt-3 text-sm leading-relaxed text-(--color-ink-muted)">
                Our{" "}
                <Link
                  href="/privacy-policy"
                  className="font-medium text-(--color-navy) underline underline-offset-2 transition-colors hover:text-(--color-gold)"
                >
                  Privacy Policy
                </Link>{" "}
                is unchanged and still available in full.
              </p>
            </div>

            <Link
              href="/"
              className="mt-8 inline-flex items-center gap-2 text-sm font-semibold text-(--color-navy) transition-colors hover:text-(--color-gold)"
            >
              <ArrowLeft className="h-4 w-4" aria-hidden="true" />
              Back to home
            </Link>
          </div>
        </div>
      </main>
      <SiteFooter variant="photo" />
    </div>
  );
}
