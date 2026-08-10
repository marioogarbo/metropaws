import type { Faq } from "@/types/faq";
import { FaqAccordion } from "@/components/faq-accordion";
import { fetchPublicContent } from "@/lib/public-content";
import { Phone, Mail } from "lucide-react";
import Link from "next/link";

const FALLBACK_FAQS: Faq[] = [
  {
    id: "fallback-1",
    question: "Is MetroPaws free?",
    answer:
      "Creating an account and registering your pet is completely free. Paid annual plans (Standard, Deluxe, Premium) unlock wellness benefits, and you only pay when you activate one. MetroPaws is a membership club, not insurance or an HMO.",
    sort_order: 0,
    is_published: true,
  },
  {
    id: "fallback-2",
    question: "How do payments and claims work?",
    answer:
      "For a scheduled visit — grooming, vaccination, a check-up — request it in the app before you go and we pay the provider directly, so you skip the out-of-pocket. Prefer to pay yourself, or it is an emergency? Pay the provider, upload the receipt, and we reimburse you to your GCash or bank. Either way, the app tracks your annual benefit to the peso.",
    sort_order: 1,
    is_published: true,
  },
  {
    id: "fallback-3",
    question: "Do I have to switch to a partner clinic?",
    answer:
      "No. Use the vet your pet already trusts. MetroPaws partners across Las Piñas offer extra member perks, but you are never required to switch providers to claim your benefits.",
    sort_order: 2,
    is_published: true,
  },
  {
    id: "fallback-4",
    question: "What are PawPoints?",
    answer:
      "PawPoints are loyalty points that reward responsible pet ownership. Earn them by joining, renewing, referring friends, completing approved claims, and attending events, then redeem for badges, pet ID tags, wellness-credit boosters, and more.",
    sort_order: 3,
    is_published: true,
  },
  {
    id: "fallback-5",
    question: "Can I manage multiple pets?",
    answer:
      "Yes. Add every pet in your household — dogs, cats, or both. Each pet gets its own Digital Pet Passport with profile, vaccination, grooming, and consultation records, all under one account.",
    sort_order: 4,
    is_published: true,
  },
  {
    id: "fallback-6",
    question: "How do I show my membership at the clinic?",
    answer:
      "Open the MetroPaws app and show your pet's QR Pet ID at check-in. It loads from your account in a few seconds, so keep a mobile-data or Wi-Fi connection handy when you arrive.",
    sort_order: 5,
    is_published: true,
  },
];

async function fetchFaqs(): Promise<Faq[]> {
  try {
    const response = await fetchPublicContent("/faqs");
    if (!response) {
      return FALLBACK_FAQS;
    }
    const data = (await response.json()) as Faq[];
    if (!Array.isArray(data) || data.length === 0) {
      return FALLBACK_FAQS;
    }
    return [...data].sort((a, b) => a.sort_order - b.sort_order);
  } catch {
    return FALLBACK_FAQS;
  }
}

export async function FaqSection() {
  const faqs = await fetchFaqs();

  return (
    <section id="faq" className="bg-(--color-cream-warm) py-20 md:py-28">
      <div className="max-w-6xl mx-auto px-6">
        <div className="grid lg:grid-cols-[1fr_2fr] gap-12 lg:gap-20 items-start">
          <div className="lg:sticky lg:top-28">
            <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
              Questions
            </p>
            <h2 className="text-3xl md:text-4xl font-bold text-(--color-navy) tracking-tight leading-tight mt-3">
              Everything you need to know
            </h2>
            <p className="text-sm text-(--color-ink) leading-relaxed mt-4 max-w-[42ch]">
              How the membership works, what your benefits cover, and what to
              expect at your first visit.
            </p>
          </div>

          <FaqAccordion faqs={faqs} />
        </div>

        <div id="contact" className="mt-16 pt-10 border-t border-(--color-ink-faint)">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-5">
            <p className="text-sm text-(--color-ink-muted)">
              Still have a question? We&apos;re easy to reach.
            </p>
            <div className="flex flex-wrap gap-x-8 gap-y-3">
              <Link
                href="tel:09209224486"
                className="flex items-center gap-2 text-sm font-medium text-(--color-ink) hover:text-(--color-navy) transition-colors group"
              >
                <Phone className="w-4 h-4 text-(--color-ink-faint) group-hover:text-(--color-navy) transition-colors shrink-0" />
                0920-922-4486
              </Link>
              <Link
                href="mailto:csr@metropaws.ph"
                className="flex items-center gap-2 text-sm font-medium text-(--color-ink) hover:text-(--color-navy) transition-colors group"
              >
                <Mail className="w-4 h-4 text-(--color-ink-faint) group-hover:text-(--color-navy) transition-colors shrink-0" />
                csr@metropaws.ph
              </Link>
              <Link
                href="https://www.facebook.com/people/Metropaws/61588899502470/"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 text-sm font-medium text-(--color-ink) hover:text-(--color-navy) transition-colors group"
              >
                <svg
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  className="w-4 h-4 text-(--color-ink-faint) group-hover:text-(--color-navy) transition-colors shrink-0"
                  aria-hidden="true"
                >
                  <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z" />
                </svg>
                Message us on Facebook
              </Link>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
