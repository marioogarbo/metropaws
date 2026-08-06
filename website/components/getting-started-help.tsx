import Image from "next/image";
import Link from "next/link";
import { PLAY_STORE_URL } from "@/lib/app-download";

const SUPPORT_EMAIL = "csr@metropaws.ph";

/**
 * The reason most people open a guide like this is that something already went
 * wrong, so this answers the cases support actually receives. Dividers only,
 * matching the FAQ accordion: no card wrappers.
 */
const answers = [
  {
    question: "The code ran out before I paid.",
    answer:
      "Nothing was charged. Open your pet's card, tap Complete Payment again, and a new code appears.",
  },
  {
    question: "I paid but my plan is not showing.",
    answer: `Close the app and open it again. It rechecks your payment every time it loads, so a plan that was paid for will appear on its own. If it is still missing, send us the reference number from your GCash or bank receipt at ${SUPPORT_EMAIL} and we will sort it out.`,
  },
  {
    question: "Do I need a credit card?",
    answer:
      "No. QR Ph works straight from e-wallet and bank apps, so you can pay without a card at all.",
  },
  {
    question: "Can I add a second pet?",
    answer:
      "Yes. Add another pet from your dashboard and it runs through the same three steps, with its own plan and its own payment.",
  },
];

export function GettingStartedHelp() {
  return (
    <section
      aria-labelledby="getting-started-help-heading"
      className="bg-(--color-cream-warm) border-y border-(--color-ink-faint) py-16 md:py-20"
    >
      <div className="max-w-6xl mx-auto px-6">
        <div className="lg:grid lg:grid-cols-[minmax(0,22rem)_minmax(0,1fr)] lg:gap-16">
          <h2
            id="getting-started-help-heading"
            className="mp-reveal text-2xl md:text-3xl font-bold text-(--color-navy) tracking-tight leading-tight text-balance"
          >
            If something looks wrong
          </h2>

          <dl className="mp-reveal mt-8 lg:mt-0">
            {answers.map(({ question, answer }, index) => (
              <div
                key={question}
                className={
                  index === 0
                    ? "pb-6"
                    : "border-t border-(--color-ink-faint) pt-6 pb-6 last:pb-0"
                }
              >
                <dt className="text-sm font-semibold text-(--color-navy)">
                  {question}
                </dt>
                <dd className="mt-2 text-sm text-(--color-ink-muted) leading-relaxed max-w-[68ch]">
                  {answer}
                </dd>
              </div>
            ))}
          </dl>
        </div>
      </div>
    </section>
  );
}

/**
 * What an active plan looks like, then the two things to do next. The dashboard
 * shot earns its place here: it is the payoff the six steps lead to.
 */
export function GettingStartedCta() {
  return (
    <section
      aria-labelledby="getting-started-cta-heading"
      className="bg-(--color-navy) py-16 md:py-20"
    >
      <div className="max-w-6xl mx-auto px-6">
        <div className="mp-reveal flex flex-col gap-10 lg:flex-row lg:items-center lg:gap-16">
          <div className="lg:flex-1">
            <h2
              id="getting-started-cta-heading"
              className="text-2xl md:text-3xl font-bold text-white tracking-tight leading-tight text-balance"
            >
              Then your pet has a card
            </h2>
            <p className="mt-3 text-sm text-white/70 leading-relaxed max-w-[52ch]">
              Once the plan is active, your pet&apos;s card carries both benefits,
              what is left in each to the peso, and the QR Pet ID you show at the
              clinic.
            </p>

            <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:items-center">
              <a
                href={PLAY_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center rounded-lg bg-(--color-gold) px-6 py-3 text-sm font-semibold text-(--color-navy) transition-all duration-150 ease-out hover:brightness-105 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-navy)"
              >
                Get the app on Google Play
              </a>
              <Link
                href="/#pricing"
                className="inline-flex items-center justify-center rounded-lg border border-white/30 px-6 py-3 text-sm font-semibold text-white transition-colors duration-150 ease-out hover:bg-white/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-navy)"
              >
                See plans and pricing
              </Link>
            </div>
          </div>

          <div className="shrink-0 w-full max-w-50 lg:max-w-60 mx-auto lg:mx-0">
            <div className="overflow-hidden rounded-xl border border-white/15">
              <Image
                src="/app-home-screen.png"
                alt="A MetroPaws dashboard showing a pet's card with its preventive wellness and emergency benefit balances, a File a claim link, and a Show Digital Pawprint button."
                width={432}
                height={930}
                sizes="(max-width: 1024px) 200px, 240px"
                className="w-full h-auto"
              />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
