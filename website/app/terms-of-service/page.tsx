import type { Metadata } from "next";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { LegalPageLayout } from "@/components/legal-page-layout";
import { DocumentUnderRevision } from "@/components/document-under-revision";
import { AGREEMENT_UNDER_REVISION } from "@/lib/legal-documents";
import { cn } from "@/lib/utils";

// This page IS the Membership Agreement (the app's agreementUrl points here), so
// it goes dark with it. The terms below are left in place: flipping the flag in
// lib/legal-documents.ts publishes them again.
export const metadata: Metadata = AGREEMENT_UNDER_REVISION
  ? {
      title: "Membership Agreement | MetroPaws Wellness Club",
      description:
        "Our Membership Agreement is being updated. The revised version will be published here.",
      // Keep a placeholder out of search results.
      robots: { index: false, follow: true },
    }
  : {
      title: "Membership Agreement | MetroPaws Wellness Club",
      description:
        "MP-CON-001 Rev. 5A — the agreement that governs your MetroPaws membership: activation, benefit eligibility, Service Authorization, provider settlement and your rights as a member.",
    };

const sections = [
  { id: "nature", title: "1. Nature of MetroPaws Membership" },
  { id: "plans-and-fees", title: "2. Membership Plans, Fees and Plan Schedule" },
  { id: "term-and-renewal", title: "3. Membership Term, Activation and Renewal" },
  { id: "registered-pet", title: "4. Registered Pet and Pet Identity Rule" },
  { id: "activation-and-eligibility", title: "5. Payment, Activation and Benefit Eligibility" },
  { id: "service-authorization", title: "6. Service Authorization Model" },
  { id: "advance-notice", title: "7. Advance Notice and Scheduling" },
  { id: "provider-verification", title: "8. Provider Verification and Repeat Use" },
  { id: "provider-acceptance", title: "9. Provider Acceptance and Member Share" },
  { id: "cancellation", title: "10. Cancellation, No-Show and Expiry" },
  { id: "settlement", title: "11. Completion, Billing and Direct Payment" },
  { id: "exception-reimbursement", title: "12. Exception Reimbursement" },
  { id: "emergency", title: "13. Emergency and Unplanned Care" },
  { id: "pet-passport", title: "14. Digital Pet Passport and Records" },
  { id: "pawpoints", title: "15. PawPoints, Community and Privileges" },
  { id: "member-responsibilities", title: "16. Member Responsibilities" },
  { id: "fraud", title: "17. Fraud, Misrepresentation and Abuse" },
  { id: "independent-providers", title: "18. Independent Providers and Liability" },
  { id: "no-guarantee", title: "19. No Guarantee of Savings or Availability" },
  { id: "data-privacy", title: "20. Data Privacy and Information Sharing" },
  { id: "termination", title: "21. Suspension, Termination and Refunds" },
  { id: "program-updates", title: "22. Program Updates and Version Control" },
  { id: "notices", title: "23. Notices and Communications" },
  { id: "governing-law", title: "24. Governing Law and Disputes" },
  { id: "entire-agreement", title: "25. Entire Agreement and Severability" },
  { id: "acceptance", title: "26. Acceptance" },
  { id: "schedule-a", title: "Schedule A — Key Member Rules" },
  { id: "schedule-b", title: "Schedule B — Digital Acceptance" },
  { id: "contact", title: "Contact" },
];

export default function TermsOfServicePage() {
  if (AGREEMENT_UNDER_REVISION) {
    return <DocumentUnderRevision documentName="Membership Agreement" />;
  }

  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-col flex-1">
        <LegalPageLayout
          eyebrow="Legal"
          title="Membership Agreement"
          lastUpdated="August 13, 2026"
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

/** A numbered clause of the agreement. Every clause is a scroll-spy target. */
function Clause({
  id,
  title,
  children,
}: {
  id: string;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section
      id={id}
      className="mt-10 pt-10 border-t border-(--color-ink-faint) scroll-mt-32"
    >
      <h2 className="text-xl font-bold text-(--color-navy) tracking-tight mb-4">
        {title}
      </h2>
      {children}
    </section>
  );
}

function Paragraph({ children }: { children: React.ReactNode }) {
  return (
    <p className="text-sm text-(--color-ink) leading-relaxed mb-4">{children}</p>
  );
}

function Subheading({ children }: { children: React.ReactNode }) {
  return (
    <h3 className="text-sm font-semibold text-(--color-navy) mt-6 mb-2">
      {children}
    </h3>
  );
}

function Bullets({ items }: { items: string[] }) {
  return (
    <ul className="list-disc pl-5 space-y-2 text-sm text-(--color-ink) leading-relaxed mb-4">
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  );
}

/**
 * The agreement carries several rule tables. They stay legible on a phone by
 * scrolling inside their own card rather than squeezing the column.
 */
function RuleTable({ headers, rows }: { headers: string[]; rows: string[][] }) {
  return (
    <div className="mb-5 overflow-x-auto rounded-xl border border-(--color-ink-faint)">
      <table className="w-full min-w-136 border-collapse text-sm">
        <thead>
          <tr className="bg-(--color-cream-warm)">
            {headers.map((header) => (
              <th
                key={header}
                scope="col"
                className="text-left align-bottom font-semibold text-(--color-navy) px-4 py-3 border-b border-(--color-ink-faint)"
              >
                {header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr
              key={row[0]}
              className="border-b border-(--color-ink-faint) last:border-b-0"
            >
              {row.map((cell, column) => (
                <td
                  key={headers[column]}
                  className={cn(
                    "px-4 py-3 align-top leading-relaxed text-(--color-ink)",
                    column === 0 && "font-semibold text-(--color-navy)",
                  )}
                >
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function TermsContent() {
  return (
    <div className="max-w-[65ch]">
      <div className="bg-(--color-cream-warm) rounded-xl p-5 mb-8">
        <p className="text-xs font-semibold uppercase tracking-widest text-(--color-gold) mb-2">
          MP-CON-001 · Revision 5A
        </p>
        <p className="text-sm font-semibold text-(--color-navy) mb-1">
          Service Authorization, Annual and Monthly Activation Edition
        </p>
        <p className="text-sm text-(--color-ink) leading-relaxed">
          For Standard, De Luxe, Premium and other approved MetroPaws membership
          plans. Rev. 5A replaces the Wellness Wallet and routine reimbursement
          model with advance Service Authorization and direct provider settlement.
        </p>
      </div>

      <Paragraph>
        This MetroPaws Membership Agreement (the “Agreement”) is entered into by
        and between MetroPaws Wellness Club Philippines Inc. (“MetroPaws”,
        “Company”, “we”, “us” or “our”) and the approved individual identified in
        the Membership Application, app registration, website registration, office
        registration or digital acceptance record (the “Member”, “you” or “your”).
      </Paragraph>
      <Paragraph>
        By signing physically, clicking an acceptance button, completing OTP or
        equivalent verification, paying a membership fee, activating an account,
        submitting a Service Request, presenting an authorization, or using a
        MetroPaws benefit, the Member agrees to this Agreement and the then-current
        Member Manual, Plan Schedule,{" "}
        <a
          href="/privacy-policy"
          className="underline hover:text-(--color-navy) transition-colors"
        >
          Privacy Notice
        </a>
        , PawPoints rules and official program advisories.
      </Paragraph>

      <Clause id="nature" title="1. Nature of MetroPaws Membership">
        <Bullets
          items={[
            "MetroPaws is a preventive pet wellness membership club, digital wellness platform and service-coordination network.",
            "MetroPaws is not an insurance company, insurance provider, health maintenance organization, veterinary clinic, animal hospital, grooming salon or emergency facility.",
            "MetroPaws does not diagnose, prescribe, treat, vaccinate, groom or guarantee any clinical, medical, safety or service outcome.",
            "Independent providers remain responsible for professional judgment, service quality, licensing, permits, pricing and acts or omissions.",
            "Membership benefits are contractual club benefits subject to eligibility, plan limits, advance authorization, provider availability, member payment status and program rules.",
          ]}
        />
      </Clause>

      <Clause id="plans-and-fees" title="2. Membership Plans, Fees and Plan Schedule">
        <Paragraph>
          MetroPaws may offer Standard, De Luxe, Premium or other approved plans.
          Current fees, covered service categories, annual service benefit limits,
          member co-payments, utilization intervals, waiting periods, exclusions and
          privileges shall be stated in the official Plan Schedule or app dashboard
          applicable at activation or renewal.
        </Paragraph>
        <Paragraph>
          Plan descriptions and future pricing may be changed prospectively with
          appropriate notice. A benefit limit is not cash, stored value, a deposit
          account, legal tender or an amount withdrawable by the Member.
        </Paragraph>
      </Clause>

      <Clause id="term-and-renewal" title="3. Membership Term, Activation and Renewal">
        <Bullets
          items={[
            "Membership becomes active only after MetroPaws completes registration, agreement acceptance, payment verification, Pet ID setup, required pet information and official system activation.",
            "The standard term is one year unless the official offer states otherwise.",
            "Renewal is subject to then-current fees, rules, benefit design, payment status and updated acceptance requirements.",
            "Unused benefits and privileges expire at the end of the term unless an official rule expressly allows carry-forward.",
          ]}
        />
      </Clause>

      <Clause id="registered-pet" title="4. Registered Pet and Pet Identity Rule">
        <Bullets
          items={[
            "Benefits are pet-specific and apply only to the registered pet identified in the Digital Pet Passport or Pet ID.",
            "Benefits may not be transferred, shared, sold, assigned or used for another pet, member, household or person unless MetroPaws expressly approves a multi-pet arrangement.",
            "The Member must provide accurate identifying details, current photographs and supporting wellness or veterinary records reasonably required for verification.",
            "MetroPaws may require identity re-verification when pet substitution, duplicate use, unusual utilization or inconsistent records are detected.",
          ]}
        />
      </Clause>

      <Clause
        id="activation-and-eligibility"
        title="5. Annual and Monthly Payment, Activation and Benefit Eligibility Rules"
      >
        <Paragraph>
          Membership and digital account activation do not automatically mean that
          every service benefit is immediately available. Annual and monthly payment
          arrangements have different activation and benefit-eligibility controls.
          All of this Section 5 applies together with the Plan Schedule, service
          authorization rules, waiting periods, exclusions and approved benefit
          limits.
        </Paragraph>

        <Subheading>5.1 Annual Membership Activation</Subheading>
        <Paragraph>
          A Member who pays the approved annual membership fee in full may become
          eligible for the applicable annual service benefits upon official
          activation, provided that MetroPaws has completed registration, agreement
          acceptance, payment verification, Digital Pet Passport or Pet ID setup,
          required pet information and any plan-specific onboarding requirements.
        </Paragraph>
        <Bullets
          items={[
            "Annual payment does not by itself guarantee provider availability, automatic service approval or payment for an unapproved service.",
            "Every planned consultation, vaccination, deworming, grooming or other designated service remains subject to advance Service Authorization, plan limits, waiting periods, service intervals, exclusions, provider confirmation and fraud controls.",
            "No service obtained before the official Membership Effective Date is retroactively payable unless MetroPaws approves a written exception.",
            "If the annual payment is reversed, dishonored, refunded, disputed or cancelled, MetroPaws may suspend or cancel digital access, benefit eligibility and outstanding authorizations, subject to applicable law and approved policy.",
          ]}
        />

        <Subheading>
          5.2 Monthly Installment Subscription Activation Is Conditional
        </Subheading>
        <Paragraph>
          A Member who chooses the monthly installment subscription shall not be
          entitled to full service-benefit utilization immediately upon payment of
          the first monthly installment. Monthly subscription activation is
          conditional and requires completion of registration, payment verification,
          Digital Pet Passport or Pet ID issuance, agreement acceptance and the
          consecutive-payment preconditions in this Section.
        </Paragraph>

        <Subheading>
          5.3 Initial Account Activation After First Monthly Payment
        </Subheading>
        <Paragraph>
          Upon successful payment of the first monthly installment and completion of
          onboarding requirements, MetroPaws may activate the Member account for
          digital access only. Digital access may include the app, Digital Pet
          Passport, pet profile management, wellness reminders, PawPoints account
          creation, community access, educational content and other low-risk digital
          features. Initial digital activation does not automatically unlock full
          Service Authorization eligibility or direct Provider Settlement.
        </Paragraph>

        <Subheading>5.4 Consecutive Payment Requirement</Subheading>
        <Paragraph>
          A monthly subscriber must complete the required number of consecutive,
          uninterrupted and successfully cleared monthly payments before becoming
          eligible to request designated planned service benefits, direct provider
          payment, emergency support, approved exception reimbursement or other
          higher-value benefits. This requirement protects financial sustainability
          and reduces enrollment solely for immediate high-value utilization.
        </Paragraph>

        <Subheading>
          5.5 Minimum Vesting and Service Authorization Controls
        </Subheading>
        <Paragraph>
          Unless modified through an officially approved Plan Schedule or program
          notice accepted for the applicable membership term, the following minimum
          launch controls shall apply:
        </Paragraph>
        <RuleTable
          headers={[
            "Monthly Plan",
            "Digital Access",
            "Full Planned-Service Eligibility",
            "Emergency Support Control",
          ]}
          rows={[
            [
              "Standard",
              "After first cleared payment and completed onboarding",
              "After six (6) consecutive monthly payments",
              "Minimum three (3) consecutive payments or as specifically approved",
            ],
            [
              "De Luxe",
              "After first cleared payment and completed onboarding",
              "After eight (8) consecutive monthly payments",
              "Minimum three (3) consecutive payments or as specifically approved",
            ],
            [
              "Premium",
              "After first cleared payment and completed onboarding",
              "After ten (10) consecutive monthly payments",
              "Minimum four (4) consecutive payments or as specifically approved",
            ],
          ]}
        />
        <Paragraph>
          Full planned-service eligibility means the Member may submit a Service
          Request for eligible consultation, vaccination, deworming, grooming or
          other covered categories. It does not mean automatic approval. Every
          request remains subject to benefit availability, service interval, advance
          notice, provider verification or acceptance, authorization validity,
          exclusions, member share and other controls.
        </Paragraph>

        <Subheading>5.6 Payment Default, Suspension and Reset Rule</Subheading>
        <Paragraph>
          Any missed, late, reversed, dishonored, cancelled, refunded or disputed
          monthly payment may result in suspension of service-benefit eligibility,
          cancellation or expiry of pending authorizations, and restriction of direct
          provider payment. MetroPaws may reset the consecutive-payment qualification
          period to zero or restore it only to the last approved good-standing
          status, depending on the account history, reason for default and approved
          payment-risk policy.
        </Paragraph>
        <Bullets
          items={[
            "A suspended Member may retain limited digital access where appropriate, but may not rely on MetroPaws payment for a new or pending service unless expressly approved.",
            "Payment made after suspension does not automatically revive an expired or cancelled authorization; a new eligibility check and Service Request may be required.",
            "MetroPaws may apply stricter controls, manual review or additional payment requirements when unusual utilization, fraud, abuse, repeated default or incomplete records are detected.",
          ]}
        />

        <Subheading>5.7 Member Status and Communication</Subheading>
        <Paragraph>
          The app, invoice, official notice or account dashboard may display status
          labels including Pending Onboarding, Digital Access Active, Vesting in
          Progress, Fully Service-Eligible, Authorization Restricted, Suspended,
          Expired or Under Review. The Member is responsible for reviewing the
          current membership, payment and benefit status before requesting or
          receiving a service.
        </Paragraph>

        <Subheading>5.8 No Retroactive Service Benefit Before Eligibility</Subheading>
        <Paragraph>
          A monthly subscriber may not request MetroPaws payment, direct provider
          settlement or reimbursement for a service obtained before the applicable
          benefit-eligibility date, even if the Member later completes the required
          monthly installments. Earlier payments do not make prior services payable.
          Any launch-period or exceptional approval must be expressly documented by
          MetroPaws in writing.
        </Paragraph>

        <Subheading>5.9 Annual Payment Exception and Immediate Eligibility</Subheading>
        <Paragraph>
          A Member who pays the approved annual fee in full may be eligible for
          applicable planned-service benefits immediately upon official activation,
          without completing monthly vesting periods, but remains subject to the Plan
          Schedule, waiting periods, service limits, Service Authorization, provider
          availability, exclusions, member share, fraud controls and this Agreement.
        </Paragraph>

        <Subheading>
          5.10 Relationship Between Activation and Service Authorization
        </Subheading>
        <Paragraph>
          Account activation, benefit eligibility, Service Authorization and Provider
          Settlement are separate events. Account activation permits access to the
          MetroPaws platform. Benefit eligibility permits the Member to request a
          covered service. Service Authorization approves a specific provider, pet,
          service, amount and validity period. Provider Settlement occurs only after
          confirmed service completion and billing validation.
        </Paragraph>
      </Clause>

      <Clause id="service-authorization" title="6. Service Authorization Model">
        <Paragraph>
          For planned eligible services, MetroPaws shall ordinarily pay the verified
          provider directly after service completion and validation. The Member must
          obtain advance Service Authorization before relying on MetroPaws payment.
        </Paragraph>
        <RuleTable
          headers={["Stage", "Member-Facing Rule"]}
          rows={[
            [
              "Service Request",
              "Member submits the registered pet, service category, preferred provider and proposed schedule.",
            ],
            [
              "Eligibility Review",
              "MetroPaws checks membership, payment status, waiting period, service interval, benefit availability, exclusions and duplicate requests.",
            ],
            [
              "Provider Verification",
              "For the first transaction with a provider, MetroPaws verifies provider identity, service capability, pricing, billing and payment process.",
            ],
            [
              "Authorization",
              "MetroPaws issues a reference number or QR containing the approved provider, service, validity period and approved MetroPaws amount.",
            ],
            [
              "Service Completion",
              "Provider confirms the authorized service and submits acceptable billing and supporting records.",
            ],
            [
              "Provider Settlement",
              "MetroPaws settles only a completed, matched and approved transaction.",
            ],
          ]}
        />
        <Paragraph>
          An authorization is not cash, not a guarantee of treatment, not a guarantee
          of provider acceptance and not final payment. Settlement occurs only after
          all required conditions are satisfied.
        </Paragraph>
      </Clause>

      <Clause id="advance-notice" title="7. Advance Notice and Scheduling">
        <Paragraph>
          Because consultation, vaccination, deworming and grooming are planned
          services, the Member must request authorization sufficiently before the
          preferred appointment. Unless a different period is shown in the app or
          official notice, the following launch standards apply:
        </Paragraph>
        <RuleTable
          headers={["Service", "Recommended Minimum Notice"]}
          rows={[
            ["Routine consultation", "At least one business day"],
            ["Vaccination or deworming", "At least two business days"],
            ["Grooming", "At least two business days"],
            [
              "Urgent but non-emergency request",
              "As early as practicable; approval is case-specific",
            ],
          ]}
        />
        <Bullets
          items={[
            "Submitting a request does not confirm the appointment. The provider must accept or confirm availability.",
            "The Member must not assume MetroPaws will pay a walk-in or unapproved service.",
            "Rescheduled appointments may require revalidation or a new authorization.",
            "Authorization validity expires automatically after the approved period.",
          ]}
        />
      </Clause>

      <Clause
        id="provider-verification"
        title="8. First-Use Provider Verification and Repeat Provider Use"
      >
        <Paragraph>
          When the Member selects a provider not yet verified in the MetroPaws
          Provider Master, MetroPaws may contact the provider to confirm identity,
          contact person, service capability, price, billing documentation and
          preferred payment channel. The Member authorizes MetroPaws to disclose the
          minimum information reasonably necessary to coordinate the requested
          service.
        </Paragraph>
        <Paragraph>
          Once the provider is verified and successfully completes a MetroPaws
          transaction, succeeding services with the same provider may follow
          simplified processing. MetroPaws may nevertheless re-verify the provider
          when contact, ownership, branch, price, bank or e-wallet details change, or
          when fraud, quality or payment risk is identified.
        </Paragraph>
      </Clause>

      <Clause
        id="provider-acceptance"
        title="9. Provider Acceptance, Service Changes and Member Share"
      >
        <Bullets
          items={[
            "The provider may accept, decline or propose a different schedule. MetroPaws does not guarantee that any specific provider, branch, veterinarian, groomer, product or appointment will be available.",
            "The provider must deliver only the authorized service unless MetroPaws approves a change.",
            "Any amount above the approved MetroPaws portion, including excess price, non-covered item, upgrade, medicine, additional test, tax or member co-payment, remains the Member’s responsibility unless expressly stated otherwise.",
            "The Member should verify the authorization and expected personal payment before the service begins.",
          ]}
        />
      </Clause>

      <Clause id="cancellation" title="10. Cancellation, Rescheduling, No-Show and Expiry">
        <Bullets
          items={[
            "The Member must cancel or reschedule through the app or official support channel before the provider or MetroPaws cut-off.",
            "A cancelled, expired or no-show authorization does not create a provider payable and normally does not consume the service benefit.",
            "If the provider imposes a disclosed cancellation fee, MetroPaws is not responsible unless the fee was expressly authorized.",
            "Repeated no-shows, abusive reservations or repeated late cancellations may result in temporary booking restrictions, suspension or termination.",
            "Provider-initiated cancellation shall not consume the Member benefit, but the Member may need to submit a new request for a replacement provider or date.",
          ]}
        />
      </Clause>

      <Clause
        id="settlement"
        title="11. Service Completion, Billing and Direct Provider Payment"
      >
        <Bullets
          items={[
            "The provider must validate the authorization and the registered pet before service.",
            "After service, the provider must confirm completion and submit an invoice, official receipt, billing statement, service record or other evidence acceptable to MetroPaws.",
            "MetroPaws may match the authorization, completion record and billing before payment.",
            "The provider may be paid per transaction or through a consolidated scheduled payout, depending on provider status and agreement. The settlement schedule does not change the Member’s approved benefit once service completion is validated.",
            "The Member must not pay the MetroPaws-covered amount unless instructed by MetroPaws or the provider under an approved exception.",
          ]}
        />
      </Clause>

      <Clause id="exception-reimbursement" title="12. Exception Reimbursement">
        <Paragraph>
          Direct provider settlement is the normal process. Reimbursement may be
          permitted only as an exception, including urgent care, verified system
          outage, provider refusal of direct settlement, geographic-access limitations
          or another written management-approved circumstance.
        </Paragraph>
        <Bullets
          items={[
            "The Member must obtain approval as early as reasonably possible.",
            "The Member must submit truthful proof of service and payment within the required period.",
            "Reimbursement is subject to plan limits, applicable rates, duplicate checks, provider confirmation and final approval.",
            "No reimbursement is guaranteed merely because the Member paid a provider.",
          ]}
        />
      </Clause>

      <Clause id="emergency" title="13. Emergency and Unplanned Care">
        <Paragraph>
          In an emergency, the Member should prioritize the pet’s safety and seek an
          appropriate licensed provider. MetroPaws does not provide emergency
          dispatch, triage or guaranteed payment. The Member should contact MetroPaws
          as soon as reasonably possible. Any emergency assistance or exception
          reimbursement is subject to the applicable plan, eligibility, documentary
          requirements, limits and approval.
        </Paragraph>
      </Clause>

      <Clause
        id="pet-passport"
        title="14. Digital Pet Passport, Wellness Dashboard and Records"
      >
        <Paragraph>
          MetroPaws may provide a Digital Pet Passport, preventive-care dashboard,
          reminders, Wellness Score, service history and related tools. These tools
          are for wellness management and engagement only. They do not replace
          official veterinary records, diagnosis, professional advice or emergency
          assessment.
        </Paragraph>
        <Bullets
          items={[
            "The Member is responsible for reviewing records and reporting inaccuracies.",
            "Wellness Score or compliance indicators reflect verified engagement only and do not guarantee health.",
            "MetroPaws may obtain service completion data from providers to update the registered pet’s records.",
          ]}
        />
      </Clause>

      <Clause id="pawpoints" title="15. PawPoints, Community and Member Privileges">
        <Paragraph>
          PawPoints are loyalty and engagement points, not cash or legal tender. They
          may be earned, redeemed, adjusted, suspended or expired according to current
          rules. Community access, educational events, campaigns, rewards and
          recognition are privileges subject to capacity, availability and conduct
          standards.
        </Paragraph>
      </Clause>

      <Clause id="member-responsibilities" title="16. Member Responsibilities">
        <Bullets
          items={[
            "Keep personal, contact, payment and pet information accurate and current.",
            "Maintain membership payments and account good standing.",
            "Use benefits only for the registered pet and approved purpose.",
            "Submit Service Requests early and review authorization conditions before visiting the provider.",
            "Pay any disclosed member share, excess or non-covered service directly to the provider.",
            "Protect account credentials and report unauthorized access promptly.",
            "Follow provider instructions and seek licensed veterinary advice for medical concerns.",
          ]}
        />
      </Clause>

      <Clause id="fraud" title="17. Fraud, Misrepresentation and Abuse">
        <Paragraph>
          Prohibited conduct includes pet substitution, duplicate authorization,
          fictitious booking, false service confirmation, collusion, altered invoice,
          provider impersonation, double collection, account sharing, benefit resale,
          manipulation of pet records, non-payment after intentional high-value
          utilization, or any attempt to circumvent plan rules.
        </Paragraph>
        <Paragraph>
          MetroPaws may reject or cancel requests, suspend authorization, hold
          payment, investigate, recover improper payments, forfeit PawPoints,
          terminate membership, disqualify future enrollment and pursue lawful
          remedies.
        </Paragraph>
      </Clause>

      <Clause
        id="independent-providers"
        title="18. Independent Providers and Limitation of Responsibility"
      >
        <Paragraph>
          Providers are independent businesses and are not employees or agents of
          MetroPaws unless a written agreement expressly states otherwise. The Member
          remains responsible for selecting a provider and making decisions concerning
          the pet’s care.
        </Paragraph>
        <Paragraph>
          To the maximum extent allowed by law, MetroPaws is not liable for provider
          negligence, malpractice, clinical judgment, diagnosis, treatment, injury,
          death, grooming outcome, product defect, provider delay, refusal, pricing
          dispute or service dissatisfaction. Nothing in this Agreement excludes
          liability that cannot lawfully be excluded.
        </Paragraph>
      </Clause>

      <Clause
        id="no-guarantee"
        title="19. No Guarantee of Savings, Utilization or Provider Availability"
      >
        <Paragraph>
          MetroPaws does not guarantee that the Member will use every benefit, receive
          savings greater than the membership fee, obtain a particular provider or
          schedule, or receive approval for every request. Actual value depends on
          eligibility, plan design, advance notice, provider acceptance, service
          utilization, member compliance and program availability.
        </Paragraph>
      </Clause>

      <Clause id="data-privacy" title="20. Data Privacy, Consent and Information Sharing">
        <Paragraph>
          The Member authorizes MetroPaws to collect, use, store and disclose personal
          information, pet information, appointment details, service records,
          invoices, payment status, app activity and related data for membership
          administration, authorization, provider coordination, settlement, fraud
          prevention, customer support, wellness reminders, analytics, legal
          compliance and legitimate business purposes, subject to the MetroPaws{" "}
          <a
            href="/privacy-policy"
            className="underline hover:text-(--color-navy) transition-colors"
          >
            Privacy Notice
          </a>{" "}
          and applicable Philippine law.
        </Paragraph>
        <Paragraph>
          Only information reasonably necessary for the requested service should be
          shared with the provider. The Member may exercise applicable privacy rights
          through MetroPaws official channels.
        </Paragraph>
      </Clause>

      <Clause id="termination" title="21. Suspension, Termination, Cancellation and Refunds">
        <Bullets
          items={[
            "MetroPaws may suspend, hold, terminate or refuse renewal for non-payment, fraud, abuse, false information, repeated no-shows, safety concerns, material breach or other reasonable program-protection grounds.",
            "Member cancellation and refunds are governed by the current cancellation and refund policy, applicable law, payment method, consumed benefits and outstanding obligations.",
            "If a service has been authorized or completed, any refund may be reduced by the value or cost of benefits already used or committed, to the extent allowed by law and disclosed policy.",
            "Termination does not remove liability for unpaid membership fees, improper benefits, provider amounts or other obligations incurred before termination.",
          ]}
        />
      </Clause>

      <Clause id="program-updates" title="22. Program Updates and Version Control">
        <Paragraph>
          MetroPaws may update future plan benefits, service limits, advance-notice
          rules, provider processes, payout arrangements, app functions, PawPoints,
          community programs and operational procedures. Material changes affecting an
          active membership shall be communicated through reasonable official channels
          and implemented subject to applicable law and contractual commitments.
        </Paragraph>
        <Paragraph>
          The platform should record the agreement version, acceptance date and time,
          Member ID, device or IP information where available, and the versions of
          related documents accepted.
        </Paragraph>
      </Clause>

      <Clause id="notices" title="23. Notices and Communications">
        <Paragraph>
          Official communications may be sent through the app, website, email, SMS,
          registered mobile number, written notice or other approved channel. The
          Member is responsible for maintaining current contact details and reviewing
          account notices.
        </Paragraph>
      </Clause>

      <Clause id="governing-law" title="24. Governing Law and Dispute Resolution">
        <Paragraph>
          This Agreement shall be governed by the laws of the Republic of the
          Philippines. The parties shall first attempt good-faith resolution through
          Customer Support, internal review and management escalation. Unresolved
          disputes may be brought before the proper court or appropriate
          dispute-resolution forum, subject to applicable law.
        </Paragraph>
      </Clause>

      <Clause
        id="entire-agreement"
        title="25. Entire Agreement, Order of Precedence and Severability"
      >
        <Paragraph>
          This Agreement shall be read with the approved Plan Schedule,{" "}
          <a
            href="/docs/member-manual.pdf"
            target="_blank"
            rel="noopener noreferrer"
            className="underline hover:text-(--color-navy) transition-colors"
          >
            Member Manual
          </a>
          , Privacy Notice, payment terms, PawPoints rules and official advisories. In
          case of conflict, the specific written plan terms accepted for the current
          membership term shall prevail over general promotional material, followed by
          this Agreement and the controlled Member Manual, subject to applicable law.
        </Paragraph>
        <Paragraph>
          If any provision is held invalid or unenforceable, the remaining provisions
          shall continue to the extent legally permitted. Failure to enforce a
          provision once does not waive future enforcement.
        </Paragraph>
      </Clause>

      <Clause id="acceptance" title="26. Member Information and Acceptance">
        <Paragraph>
          By signing or completing digital acceptance, the Member confirms that the
          Member has read, understood and accepted this Agreement, the applicable Plan
          Schedule, Member Manual, Privacy Notice and related program rules. The
          Member specifically understands that MetroPaws is not insurance, not an HMO
          and not a veterinary service provider, and that planned benefits generally
          require advance Service Authorization.
        </Paragraph>
        <div className="bg-(--color-cream-warm) rounded-xl p-5">
          <h3 className="text-sm font-semibold text-(--color-navy) mb-2">
            Digital acceptance
          </h3>
          <p className="text-sm text-(--color-ink) leading-relaxed">
            When you register on this website or in the MetroPaws app, ticking the
            acceptance box is your digital acceptance of this Agreement. MetroPaws
            records the agreement version, the acceptance date and time and your
            Member ID against your membership. Members enrolling at the office sign
            the printed Agreement, which carries the member information and signature
            block.
          </p>
        </div>
      </Clause>

      <Clause id="schedule-a" title="Schedule A — Key Member Rules Summary">
        <RuleTable
          headers={["Rule Area", "Member Rule"]}
          rows={[
            [
              "Advance Notice",
              "Request authorization before the planned provider visit; submitting a request does not confirm the appointment.",
            ],
            [
              "Direct Provider Payment",
              "MetroPaws normally pays the verified provider after matched service completion and billing.",
            ],
            [
              "First-Use Provider",
              "Provider verification may be required before the first authorization and direct payment.",
            ],
            [
              "Authorization",
              "Use only the approved pet, provider, service, date/validity and amount.",
            ],
            [
              "Member Share",
              "Pay any co-payment, excess, upgrade or non-covered amount directly to the provider.",
            ],
            [
              "Cancellation",
              "Cancel or reschedule before the cut-off; repeated no-shows may restrict booking privileges.",
            ],
            [
              "Emergency",
              "Seek appropriate care first; MetroPaws payment or reimbursement is not guaranteed.",
            ],
            [
              "Pet-Specific Benefits",
              "Benefits are non-transferable and tied to the registered Pet ID.",
            ],
            [
              "Fraud",
              "False bookings, pet substitution, collusion and duplicate payment may lead to termination and recovery.",
            ],
            [
              "Provider Independence",
              "MetroPaws does not control independent providers’ clinical or service decisions.",
            ],
          ]}
        />
      </Clause>

      <Clause id="schedule-b" title="Schedule B — Digital Acceptance Statement">
        <div className="bg-(--color-cream-warm) rounded-xl p-5">
          <p className="text-sm text-(--color-ink) leading-relaxed">
            I have read, understood and agree to the MetroPaws Membership Agreement
            Rev. 5A, the applicable Plan Schedule, Member Manual, Privacy Notice,
            PawPoints Rules and official program terms. I understand that planned
            benefits generally require advance Service Authorization; MetroPaws
            ordinarily pays a verified provider only after confirmed service
            completion and validation; MetroPaws is not insurance, not an HMO and not
            a veterinary service provider; and I remain responsible for provider
            selection, pet-care decisions and any disclosed member share or
            non-covered amount.
          </p>
        </div>
      </Clause>

      <Clause id="contact" title="Contact">
        <Paragraph>
          For questions about this Agreement, contact our customer support team:
        </Paragraph>
        <div className="bg-(--color-cream-warm) rounded-xl p-5">
          <p className="text-sm font-semibold text-(--color-navy) mb-1">
            MetroPaws Wellness Club Philippines Inc.
          </p>
          <p className="text-sm text-(--color-ink) leading-relaxed mb-3">
            #18 Apollo 3, Moonwalk Village, Talon 5, Las Piñas City, Metro Manila
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
      </Clause>
    </div>
  );
}
