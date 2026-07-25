import type { Metadata } from "next";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { LegalPageLayout } from "@/components/legal-page-layout";

export const metadata: Metadata = {
  title: "Privacy Policy | MetroPaws Wellness Club",
  description:
    "How MetroPaws collects, uses, and protects your personal information. Your rights under the Data Privacy Act of 2012 (RA 10173).",
};

const sections = [
  { id: "introduction", title: "1. Introduction" },
  { id: "information-we-collect", title: "2. Information We Collect" },
  { id: "how-we-use", title: "3. How We Use Your Information" },
  { id: "sharing", title: "4. Sharing Your Information" },
  { id: "data-retention", title: "5. Data Retention" },
  { id: "your-rights", title: "6. Your Rights Under RA 10173" },
  { id: "cookies", title: "7. Cookies" },
  { id: "data-security", title: "8. Data Security" },
  { id: "childrens-privacy", title: "9. Children's Privacy" },
  { id: "policy-changes", title: "10. Policy Changes" },
  { id: "contact", title: "11. Contact" },
];

export default function PrivacyPolicyPage() {
  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-col flex-1">
        <LegalPageLayout
          eyebrow="Legal"
          title="Privacy Policy"
          lastUpdated="June 1, 2026"
          sections={sections}
          crossLink={{ label: "Read our Terms of Service", href: "/terms-of-service" }}
        >
          <PrivacyContent />
        </LegalPageLayout>
      </main>
      <SiteFooter variant="photo" />
    </div>
  );
}

function PrivacyContent() {
  return (
    <div className="max-w-[65ch]">
      <section id="introduction" className="scroll-mt-32">
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          1. Introduction
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          MetroPaws Wellness Club (&ldquo;MetroPaws,&rdquo; &ldquo;we,&rdquo;
          &ldquo;us,&rdquo; or &ldquo;our&rdquo;) is committed to protecting the personal
          information of our members and visitors. This Privacy Policy describes what
          information we collect, how we use it, who we share it with, and your rights as
          a data subject under Republic Act No. 10173, the Data Privacy Act of 2012, and
          its Implementing Rules and Regulations.
        </p>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-5">
          By creating an account or using MetroPaws services, you consent to the
          collection and processing of your personal information as described in this
          Policy. If you do not agree, please do not use our services.
        </p>
        <div className="bg-(--color-cream-warm) rounded-xl p-5">
          <p className="text-sm text-(--color-ink) leading-relaxed">
            <span className="font-semibold text-(--color-navy)">
              Personal Information Controller:
            </span>{" "}
            MetroPaws Wellness Club, Las Piñas City, Metro Manila, Philippines.
          </p>
        </div>
      </section>

      <section
        id="information-we-collect"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          2. Information We Collect
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          We collect information in two ways: information you provide directly, and
          information collected automatically when you use our services.
        </p>
        <h3 className="text-sm font-semibold text-(--color-navy) mt-6 mb-2">
          Information you provide
        </h3>
        <ul className="list-disc pl-5 space-y-2 text-sm text-(--color-ink) leading-relaxed mb-4">
          <li>
            Full name, date of birth, and contact details (email address, mobile number)
          </li>
          <li>
            Pet information: name, species, breed, date of birth, weight, and relevant
            medical history
          </li>
          <li>
            Payment information (processed by our payment provider; we do not store full
            card details)
          </li>
          <li>
            Vaccination records and veterinary notes you upload or that partner clinics
            add during a visit
          </li>
          <li>Your barangay and city of residence within Metro Manila</li>
        </ul>
        <h3 className="text-sm font-semibold text-(--color-navy) mt-6 mb-2">
          Information collected automatically
        </h3>
        <ul className="list-disc pl-5 space-y-2 text-sm text-(--color-ink) leading-relaxed">
          <li>Device type, operating system, and browser type</li>
          <li>IP address and approximate location</li>
          <li>Pages visited, time on site, and how you navigate our platform</li>
        </ul>
      </section>

      <section
        id="how-we-use"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          3. How We Use Your Information
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          We process your personal information for the following purposes:
        </p>
        <ul className="list-disc pl-5 space-y-2 text-sm text-(--color-ink) leading-relaxed">
          <li>Create and manage your MetroPaws membership account</li>
          <li>Issue your digital QR Pet ID and membership card</li>
          <li>
            Share relevant pet records with partner clinics at the time of a visit, with
            your consent
          </li>
          <li>
            Send service communications: appointment reminders, vaccination due dates, and
            membership renewal notices
          </li>
          <li>Respond to your inquiries and provide customer support</li>
          <li>Improve our platform and services</li>
          <li>Comply with applicable Philippine law</li>
        </ul>
      </section>

      <section
        id="sharing"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          4. Sharing Your Information
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          We do not sell your personal information to third parties. We share information
          only in the following circumstances.
        </p>
        <h3 className="text-sm font-semibold text-(--color-navy) mt-6 mb-2">
          Partner clinics
        </h3>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          When you present your QR Pet ID at a partner clinic, that clinic gains access to
          your pet&apos;s profile, session history, and vaccination records relevant to
          your visit. You control which information is shared through your account
          settings.
        </p>
        <h3 className="text-sm font-semibold text-(--color-navy) mt-6 mb-2">
          Service providers
        </h3>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          We work with third-party vendors to operate our platform, including payment
          processors, cloud hosting, and email delivery services. These providers are
          bound by data processing agreements and may not use your information for their
          own purposes.
        </p>
        <h3 className="text-sm font-semibold text-(--color-navy) mt-6 mb-2">
          Legal requirements
        </h3>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          We may disclose your information if required by law, court order, or a valid
          government request.
        </p>
      </section>

      <section
        id="data-retention"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          5. Data Retention
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          We retain your personal information for as long as your membership is active or
          as needed to provide our services. If you close your account, we will delete or
          anonymize your personal information within ninety (90) days, unless we are
          required by law to retain it for a longer period.
        </p>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          Veterinary and vaccination records shared with partner clinics are retained
          according to each clinic&apos;s own record-keeping policies, which may be
          subject to separate regulatory requirements.
        </p>
      </section>

      <section
        id="your-rights"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          6. Your Rights Under RA 10173
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          As a data subject under the Data Privacy Act of 2012, you have the following
          rights:
        </p>
        <ul className="list-disc pl-5 space-y-3 text-sm text-(--color-ink) leading-relaxed mb-5">
          <li>
            <span className="font-semibold text-(--color-navy)">Be informed</span> — Know
            whether your personal information is being processed and what we hold about
            you.
          </li>
          <li>
            <span className="font-semibold text-(--color-navy)">Access</span> — Request a
            copy of the personal information we have about you.
          </li>
          <li>
            <span className="font-semibold text-(--color-navy)">Rectification</span> —
            Correct inaccurate or incomplete information.
          </li>
          <li>
            <span className="font-semibold text-(--color-navy)">Erasure or blocking</span>{" "}
            — Request deletion or blocking of your personal information under qualifying
            circumstances.
          </li>
          <li>
            <span className="font-semibold text-(--color-navy)">Object</span> — Opt out of
            processing for direct marketing or automated decision-making.
          </li>
          <li>
            <span className="font-semibold text-(--color-navy)">Data portability</span> —
            Receive your information in a structured, commonly used format.
          </li>
          <li>
            <span className="font-semibold text-(--color-navy)">Lodge a complaint</span> —
            File a complaint with the National Privacy Commission (NPC) at privacy.gov.ph.
          </li>
        </ul>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          To exercise any of these rights, contact our Data Protection Officer (see
          Section 11).
        </p>
      </section>

      <section
        id="cookies"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          7. Cookies
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          We use cookies and similar technologies to keep you signed in to your account,
          remember your preferences, and understand how visitors use our website so we can
          improve it.
        </p>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          You can control cookies through your browser settings. Disabling certain cookies
          may affect the functionality of some features.
        </p>
      </section>

      <section
        id="data-security"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          8. Data Security
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-4">
          We implement technical and organizational measures to protect your personal
          information, including:
        </p>
        <ul className="list-disc pl-5 space-y-2 text-sm text-(--color-ink) leading-relaxed mb-4">
          <li>Encrypted data transmission via HTTPS/TLS</li>
          <li>
            Access controls limiting who within our team can view personal information
          </li>
          <li>Regular security reviews of our platform</li>
        </ul>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          No electronic system is completely secure. If we become aware of a data breach
          affecting your rights, we will notify you and the National Privacy Commission as
          required under RA 10173.
        </p>
      </section>

      <section
        id="childrens-privacy"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          9. Children&apos;s Privacy
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          MetroPaws is intended for individuals eighteen (18) years of age or older. We do
          not knowingly collect personal information from minors. If you believe we have
          inadvertently collected information from a minor, please contact us so we may
          promptly delete it.
        </p>
      </section>

      <section
        id="policy-changes"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          10. Policy Changes
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          We may update this Privacy Policy from time to time. When we make material
          changes, we will notify you by email and update the &ldquo;Last updated&rdquo;
          date at the top of this page. Your continued use of MetroPaws after such changes
          constitutes your acceptance of the revised Policy.
        </p>
      </section>

      <section
        id="contact"
        className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
      >
        <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
          11. Contact
        </h2>
        <p className="text-sm text-(--color-ink) leading-relaxed mb-5">
          For questions, concerns, or data subject requests, contact our Data Protection
          Officer:
        </p>
        <div className="bg-(--color-cream-warm) rounded-xl p-5">
          <p className="text-sm font-semibold text-(--color-navy) mb-1">
            MetroPaws Wellness Club
          </p>
          <p className="text-sm text-(--color-ink) leading-relaxed mb-3">
            Attn: Data Protection Officer
            <br />
            Las Piñas City, Metro Manila, Philippines
          </p>
          <div className="flex flex-col gap-1.5">
            <a
              href="mailto:privacy@metropaws.ph"
              className="text-sm text-(--color-ink) hover:text-(--color-navy) transition-colors underline"
            >
              privacy@metropaws.ph
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
