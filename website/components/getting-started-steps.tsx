import Image from "next/image";
import {
  CheckoutScreenDiagram,
  GalleryScanDiagram,
} from "@/components/qr-ph-diagram";
import {
  CHECKOUT_WINDOW_LABEL,
  QR_PH_APPS,
  QR_PH_FALLBACK_LABEL,
} from "@/lib/payment-methods";

const appList = `${QR_PH_APPS.join(", ")}, ${QR_PH_FALLBACK_LABEL}`;

interface AppShot {
  src: string;
  alt: string;
  width: number;
  height: number;
}

interface WalkthroughStep {
  title: string;
  detail: string;
  /** Anchor, so the FAQ and the homepage rail can deep-link to the paying part. */
  id?: string;
  shot?: AppShot;
  /** The checkout screen is PayMongo's, so it is drawn rather than screenshotted. */
  showsCheckoutDiagram?: boolean;
  /** The scanning step carries the same-phone workaround. */
  showsGalleryNote?: boolean;
}

const steps: WalkthroughStep[] = [
  {
    title: "Create your account",
    detail:
      "Install MetroPaws from Google Play, then tap Join now on the sign in screen. Registering and adding your pet cost nothing. You only pay when you activate a plan.",
    shot: {
      src: "/app-sign-in.png",
      alt: "The MetroPaws sign in screen, with a Join now link at the bottom for people who do not have an account yet.",
      width: 433,
      height: 890,
    },
  },
  {
    title: "Add your pet",
    detail:
      "Adding a pet runs in three short steps: details, health card, then the plan. The three photos on the first step are required. They are how we verify a claim later.",
    shot: {
      src: "/app-add-pet-details.png",
      alt: "The first step of Add a Pet, asking for a front face, full body and with-owner photo, then the pet's name, type, sex and breed.",
      width: 438,
      height: 891,
    },
  },
  {
    title: "Choose a plan on the last step",
    detail:
      "Standard, Deluxe, or Premium, picked as you finish adding your pet. Each one lists the wellness and emergency benefit it carries, and you can upgrade later without losing what you have already used.",
    shot: {
      // Prices are visible in this screenshot and plans are editable from the
      // admin panel, so a price change in admin makes this image disagree with
      // the pricing section. Re-capture it whenever a plan price moves.
      src: "/app-choose-plan.png",
      alt: "The plan step of Add a Pet, listing Standard, Deluxe and Premium with the benefit amounts each one includes.",
      width: 435,
      height: 887,
    },
  },
  {
    title: "Tap Complete Payment",
    detail:
      "The app confirms your pet is saved and leaves one button to press. Nothing is charged until you go through it, so you can come back to this later from your pet's card.",
  },
  {
    title: "Scan the QR Ph code",
    id: "payment",
    detail: `Your total appears with nothing added on top, next to a countdown that starts at ${CHECKOUT_WINDOW_LABEL}. Open ${appList}, then scan the code on screen. If the countdown runs out, nothing is charged and you can start again.`,
    showsCheckoutDiagram: true,
    showsGalleryNote: true,
  },
  {
    title: "Your plan activates by itself",
    detail:
      "There is no proof of payment to send. The app confirms it the moment the payment clears. If you do not see it yet, close the app and open it again.",
    shot: {
      src: "/app-plan-activated.png",
      alt: "A confirmation screen reading Plan activated, with a note that sessions will appear on the pet's card.",
      width: 402,
      height: 402,
    },
  },
];

function ScreenFrame({ shot }: { shot: AppShot }) {
  return (
    <div className="overflow-hidden rounded-xl border border-(--color-ink-faint) bg-(--color-surface)">
      <Image
        src={shot.src}
        alt={shot.alt}
        width={shot.width}
        height={shot.height}
        sizes="(max-width: 768px) 200px, 240px"
        className="w-full h-auto"
      />
    </div>
  );
}

export function GettingStartedSteps() {
  return (
    <section
      aria-labelledby="getting-started-steps-heading"
      className="bg-(--color-cream) pb-20 md:pb-28"
    >
      <div className="max-w-6xl mx-auto px-6">
        <h2 id="getting-started-steps-heading" className="sr-only">
          Step by step
        </h2>

        <ol>
          {steps.map(
            (
              { title, detail, id, shot, showsCheckoutDiagram, showsGalleryNote },
              index,
            ) => {
              const isLast = index === steps.length - 1;

              return (
                <li
                  key={title}
                  id={id}
                  className={`mp-reveal relative ps-11 md:ps-14 border-l scroll-mt-28 ${
                    isLast
                      ? "border-transparent pb-0"
                      : "border-(--color-ink-faint) pb-12 md:pb-16"
                  }`}
                >
                  {/* Numeral masks the connector line behind it */}
                  <span
                    aria-hidden="true"
                    className="absolute -inset-s-4 top-0 flex h-8 w-8 items-center justify-center rounded-full bg-(--color-gold) text-sm font-bold text-(--color-navy) tabular-nums"
                  >
                    {index + 1}
                  </span>

                  <div className="md:grid md:grid-cols-[minmax(0,1fr)_15rem] md:gap-10 md:items-start">
                    <div>
                      <h3 className="text-base md:text-xl font-bold text-(--color-navy) leading-tight text-balance">
                        {title}
                      </h3>
                      <p className="mt-2 text-sm text-(--color-ink-muted) leading-relaxed max-w-[62ch]">
                        {detail}
                      </p>

                      {showsGalleryNote ? (
                        <div className="mt-5 rounded-xl border border-(--color-ink-faint) bg-(--color-cream-warm) p-4 sm:p-5 md:p-6 max-w-[62ch]">
                          <p className="text-sm font-semibold text-(--color-navy)">
                            Paying on the same phone?
                          </p>
                          <p className="mt-2 text-sm text-(--color-ink-muted) leading-relaxed">
                            A phone cannot scan its own screen. Screenshot the code
                            first. Then in your wallet app, tap Scan QR and choose
                            that screenshot from your gallery.
                          </p>
                          <GalleryScanDiagram className="mt-5 w-full max-w-60 h-auto" />
                        </div>
                      ) : null}
                    </div>

                    {shot ? (
                      <div className="mt-6 md:mt-0 w-full max-w-50 md:max-w-none">
                        <ScreenFrame shot={shot} />
                      </div>
                    ) : null}

                    {showsCheckoutDiagram ? (
                      <figure className="mt-6 md:mt-0 w-full max-w-50 md:max-w-none">
                        <div className="rounded-xl bg-(--color-navy) p-5">
                          <CheckoutScreenDiagram className="w-full h-auto" />
                        </div>
                        <figcaption className="mt-3 text-sm text-(--color-ink-muted) leading-relaxed">
                          The checkout screen, drawn rather than photographed: a real
                          one carries a live code.
                        </figcaption>
                      </figure>
                    ) : null}
                  </div>
                </li>
              );
            },
          )}
        </ol>
      </div>
    </section>
  );
}
