import type { Metadata } from "next";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { LegalPageLayout } from "@/components/legal-page-layout";

export const metadata: Metadata = {
  title: "Delete Your Account | MetroPaws Wellness Club",
  description:
    "How to request deletion of your MetroPaws account and the personal data associated with it.",
};

const sections = [
  { id: "how-to-request", title: "1. How to Request Deletion" },
  { id: "what-is-deleted", title: "2. What Is Deleted" },
  { id: "what-is-retained", title: "3. What Is Retained" },
  { id: "timeline", title: "4. Timeline" },
];

export default function DeleteAccountPage() {
  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-col flex-1">
        <LegalPageLayout
          eyebrow="Legal"
          title="Delete Your Account"
          lastUpdated="July 9, 2026"
          sections={sections}
          crossLink={{ label: "Read our Privacy Policy", href: "/privacy-policy" }}
        >
          <DeleteAccountContent />
        </LegalPageLayout>
      </main>
      <SiteFooter variant="photo" />
    </div>
  );
}

function DeleteAccountContent() {
  return (
    <div className="max-w-[65ch]">
      <section id="how-to-request" className="scroll-mt-32">
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          1. How to Request Deletion
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          You can request deletion of your MetroPaws account and the personal data
          associated with it at any time. Send an email to{" "}
          <a
            href="mailto:privacy@metropaws.ph?subject=Account%20Deletion%20Request"
            className="font-semibold text-(--color-navy) underline underline-offset-2"
          >
            privacy@metropaws.ph
          </a>{" "}
          <span className="font-semibold">from the email address registered to your
          account</span>, with the subject line &ldquo;Account Deletion Request.&rdquo;
        </p>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-5">
          We verify requests against the registered email address to protect your
          account. If you no longer have access to that email address, mention this in
          your request and we will ask for alternative proof of identity before
          proceeding.
        </p>
        <div className="bg-(--color-cream-warm) rounded-xl p-5">
          <p className="text-sm text-(--color-ink) leading-relaxed">
            <span className="font-semibold text-(--color-navy)">Note for members with
            an active plan:</span>{" "}
            deleting your account ends your membership. Unused benefits, sessions, and
            Paw Points are forfeited and membership fees are not refunded, per the
            Membership Agreement.
          </p>
        </div>
      </section>

      <section
        id="what-is-deleted"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          2. What Is Deleted
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          Once your request is verified and processed, we delete the personal data
          linked to your account, including:
        </p>
        <ul className="text-sm text-(--color-ink) leading-relaxed mb-5 list-disc pl-5 space-y-2">
          <li>Your account credentials and profile (name, email, phone, address, photo)</li>
          <li>Your pets&rsquo; profiles, photos, and vaccination records</li>
          <li>Uploaded receipts and reimbursement claim details</li>
          <li>Payout details (GCash or bank account information)</li>
          <li>In-app notifications and Paw Points history</li>
        </ul>
      </section>

      <section
        id="what-is-retained"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          3. What Is Retained
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-5">
          We may retain limited records where the law requires or permits it, such as
          payment and tax records required by Philippine regulations, and records needed
          to resolve disputes or enforce our agreements. Retained records are kept only
          as long as legally necessary and are no longer used for any other purpose. See
          our Privacy Policy for details on retention under the Data Privacy Act of 2012
          (RA 10173).
        </p>
      </section>

      <section
        id="timeline"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          4. Timeline
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-5">
          We acknowledge deletion requests within 5 business days and complete verified
          deletions within 30 days of verification. You will receive a confirmation
          email once your data has been deleted.
        </p>
      </section>
    </div>
  );
}
