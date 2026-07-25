import type { Metadata } from "next";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { LegalPageLayout } from "@/components/legal-page-layout";

export const metadata: Metadata = {
  title: "Terms of Service | MetroPaws Wellness Club",
  description:
    "The terms that govern your MetroPaws membership, including coverage, billing, and your rights as a member.",
};

const sections = [
  { id: "acceptance", title: "1. Acceptance of Terms" },
  { id: "what-metropaws-is", title: "2. What MetroPaws Is and Is Not" },
  { id: "membership-plans", title: "3. Membership Plans and Fees" },
  { id: "payment-and-billing", title: "4. Payment and Billing" },
  { id: "partner-clinic-access", title: "5. Partner Clinic Access" },
  { id: "qr-pet-id", title: "6. QR Pet ID and Digital Records" },
  { id: "acceptable-use", title: "7. Acceptable Use" },
  { id: "intellectual-property", title: "8. Intellectual Property" },
  { id: "limitation-of-liability", title: "9. Limitation of Liability" },
  { id: "governing-law", title: "10. Governing Law and Disputes" },
  { id: "termination", title: "11. Termination" },
  { id: "modifications", title: "12. Modifications to These Terms" },
  { id: "contact", title: "13. Contact" },
];

export default function TermsOfServicePage() {
  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-col flex-1">
        <LegalPageLayout
          eyebrow="Legal"
          title="Terms of Service"
          lastUpdated="June 1, 2026"
          sections={sections}
          crossLink={{ label: "Read our Privacy Policy", href: "/privacy-policy" }}
        >
          <TermsContent />
        </LegalPageLayout>
      </main>
      <SiteFooter variant="photo" />
    </div>
  );
}

function TermsContent() {
  return (
    <div className="max-w-[65ch]">
      <section id="acceptance" className="scroll-mt-32">
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          1. Acceptance of Terms
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          By creating an account, registering for a membership plan, or otherwise
          accessing MetroPaws services, you agree to be bound by these Terms of Service.
          If you do not agree, do not use our services.
        </p>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          These Terms, together with our{" "}
          <a
            href="/privacy-policy"
            className="underline hover:text-(--color-navy) transition-colors"
          >
            Privacy Policy
          </a>
          , constitute the entire agreement between you and MetroPaws Wellness Club
          regarding your use of our services.
        </p>
      </section>

      <section
        id="what-metropaws-is"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          2. What MetroPaws Is and Is Not
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-5">
          MetroPaws Wellness Club is a pet wellness membership club. It is not a
          veterinary clinic, a licensed healthcare provider, or a pet insurance company.
        </p>
        <div className="bg-(--color-cream-warm) rounded-xl p-5 mb-5">
          <h3 className="text-sm font-semibold text-(--color-navy) mb-2">
            What MetroPaws provides
          </h3>
          <ul className="list-disc pl-4 space-y-2 text-sm text-(--color-ink) leading-relaxed">
            <li>A digital membership card and QR Pet ID for your pet</li>
            <li>
              A record of your pet&apos;s veterinary visits, vaccinations, and session
              history
            </li>
            <li>
              Access to service coverage at partner clinics under the terms of your chosen
              membership plan
            </li>
            <li>A community of pet owners in Las Piñas and Metro Manila</li>
          </ul>
        </div>
        <div className="bg-(--color-cream-warm) rounded-xl p-5">
          <h3 className="text-sm font-semibold text-(--color-navy) mb-2">
            What MetroPaws does not provide
          </h3>
          <ul className="list-disc pl-4 space-y-2 text-sm text-(--color-ink) leading-relaxed">
            <li>Veterinary diagnosis, treatment recommendations, or medical advice</li>
            <li>Emergency veterinary services</li>
            <li>
              Guarantees of availability at any specific partner clinic on any specific
              date
            </li>
            <li>Coverage for services outside the scope of your membership plan</li>
          </ul>
        </div>
        <p className="text-sm text-(--color-ink) leading-relaxed mt-5">
          Any diagnosis, treatment, or medical decision is made solely by the licensed
          veterinarian at the partner clinic you visit. MetroPaws has no responsibility
          for clinical outcomes.
        </p>
      </section>

      <section
        id="membership-plans"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          3. Membership Plans and Fees
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          MetroPaws offers three membership tiers: Standard, Deluxe, and Premium. The
          specific coverage, service entitlements, and annual fees for each plan are
          described on our Pricing page and may be updated from time to time with notice.
        </p>
        <h3 className="text-sm font-semibold text-(--color-navy) mt-6 mb-2">
          Founding 50
        </h3>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          Members who joined under the Founding 50 program are entitled to their
          founding-tier pricing for as long as their membership remains active and in good
          standing without a lapse exceeding thirty (30) days. A lapse beyond this period
          forfeits the locked-in rate permanently.
        </p>
      </section>

      <section
        id="payment-and-billing"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          4. Payment and Billing
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          Membership fees are billed annually. By providing payment information and
          enrolling in a plan, you authorize MetroPaws to charge the applicable fee.
        </p>
        <h3 className="text-sm font-semibold text-(--color-navy) mt-6 mb-2">
          Non-payment
        </h3>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          If a payment fails and is not resolved within seven (7) calendar days, your
          membership will be suspended. After thirty (30) days of suspension, your
          membership will be terminated and any founding-tier pricing will be forfeited.
        </p>
        <h3 className="text-sm font-semibold text-(--color-navy) mt-6 mb-2">Refunds</h3>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          Membership fees are non-refundable except as required by applicable Philippine
          consumer protection laws.
        </p>
      </section>

      <section
        id="partner-clinic-access"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          5. Partner Clinic Access
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          Service availability depends on the network of partner clinics affiliated with
          MetroPaws at the time of your visit. Partner clinic participation may change. We
          will notify active members in advance of any clinics leaving the network.
        </p>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          Coverage at a partner clinic is subject to:
        </p>
        <ul className="list-disc pl-5 space-y-2 text-sm text-(--color-ink) leading-relaxed mb-4">
          <li>Presenting a valid QR Pet ID at check-in</li>
          <li>The service being within the scope of your membership plan</li>
          <li>The clinic having availability on the requested date</li>
        </ul>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          MetroPaws does not guarantee appointment availability or wait times at partner
          clinics.
        </p>
      </section>

      <section
        id="qr-pet-id"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          6. QR Pet ID and Digital Records
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          Your QR Pet ID is linked to your pet&apos;s profile and is valid for the
          duration of your active membership. If your membership lapses, the QR code
          remains scannable but will display a limited view only until the membership is
          renewed.
        </p>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          You are responsible for the accuracy of the pet information in your profile.
          MetroPaws is not liable for errors in records you have entered or for records
          entered by partner clinics on your behalf.
        </p>
      </section>

      <section
        id="acceptable-use"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          7. Acceptable Use
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          You agree not to:
        </p>
        <ul className="list-disc pl-5 space-y-2 text-sm text-(--color-ink) leading-relaxed">
          <li>
            Provide false or misleading information during registration or at partner
            clinics
          </li>
          <li>
            Present your QR Pet ID for a pet that is not registered under your account
          </li>
          <li>
            Attempt to access, modify, or interfere with any part of the MetroPaws
            platform or other members&apos; accounts
          </li>
          <li>Use MetroPaws services for any unlawful purpose</li>
        </ul>
      </section>

      <section
        id="intellectual-property"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          8. Intellectual Property
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          The MetroPaws name, logo, website, app design, and all content produced by
          MetroPaws are owned by MetroPaws Wellness Club and protected by applicable
          intellectual property laws. You may not reproduce, distribute, or create
          derivative works from our content without prior written permission.
        </p>
      </section>

      <section
        id="limitation-of-liability"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          9. Limitation of Liability
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          To the maximum extent permitted by Philippine law, MetroPaws Wellness Club is
          not liable for:
        </p>
        <ul className="list-disc pl-5 space-y-2 text-sm text-(--color-ink) leading-relaxed mb-4">
          <li>
            Any veterinary treatment outcomes or clinical decisions made by partner
            clinics
          </li>
          <li>Interruption or unavailability of our digital platform</li>
          <li>Loss of data due to technical failures outside our reasonable control</li>
          <li>
            Any indirect, incidental, or consequential damages arising from your use of
            our services
          </li>
        </ul>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          Our total liability to you for any claim arising from these Terms shall not
          exceed the amount you paid MetroPaws in the twelve (12) months preceding the
          claim.
        </p>
      </section>

      <section
        id="governing-law"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          10. Governing Law and Disputes
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          These Terms are governed by the laws of the Republic of the Philippines. Any
          dispute arising from or relating to these Terms or your use of MetroPaws
          services shall be subject to the exclusive jurisdiction of the courts of Las
          Piñas City, Metro Manila.
        </p>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          Before initiating formal proceedings, we encourage you to contact us at
          csr@metropaws.ph to resolve disputes informally.
        </p>
      </section>

      <section
        id="termination"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          11. Termination
        </h2>
        <h3 className="text-sm font-semibold text-(--color-navy) mt-2 mb-2">By you</h3>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          You may cancel your membership at any time by contacting us at csr@metropaws.ph.
          Cancellation takes effect at the end of the current billing period.
        </p>
        <h3 className="text-sm font-semibold text-(--color-navy) mt-6 mb-2">
          By MetroPaws
        </h3>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          We may suspend or terminate your account if you violate these Terms, fail to pay
          applicable fees, or if we reasonably believe continued access poses a risk to
          our platform or other members. We will provide notice except where immediate
          action is required to prevent harm.
        </p>
      </section>

      <section
        id="modifications"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          12. Modifications to These Terms
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          We may update these Terms from time to time. When we make material changes, we
          will notify you by email and update the &ldquo;Last updated&rdquo; date at the
          top of this page. Your continued use of MetroPaws after the effective date
          constitutes acceptance. If you disagree with any changes, you may cancel your
          membership before the effective date.
        </p>
      </section>

      <section
        id="contact"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          13. Contact
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-5">
          For questions about these Terms, contact our customer support team:
        </p>
        <div className="bg-(--color-cream-warm) rounded-xl p-5">
          <p className="text-sm font-semibold text-(--color-navy) mb-1">
            MetroPaws Wellness Club
          </p>
          <p className="text-sm text-(--color-ink) leading-relaxed mb-3">
            Las Piñas City, Metro Manila, Philippines
          </p>
          <div className="flex flex-col gap-1.5">
            <a
              href="mailto:csr@metropaws.ph"
              className="text-sm text-(--color-ink) hover:text-(--color-navy) transition-colors underline"
            >
              csr@metropaws.ph
            </a>
            <a
              href="tel:09209224486"
              className="text-sm text-(--color-ink) hover:text-(--color-navy) transition-colors"
            >
              0920-922-4486
            </a>
          </div>
        </div>
      </section>
    </div>
  );
}
