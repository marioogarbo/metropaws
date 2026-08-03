import type { Metadata } from "next";
import type { ReactNode } from "react";
import Image from "next/image";
import Link from "next/link";
import { ShieldCheck, CheckCircle2, HelpCircle, Check } from "lucide-react";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { DownloadQr } from "@/components/download-qr";
import { PlayStoreIcon } from "@/components/play-store-icon";
import { AppleLogoIcon } from "@/components/apple-logo-icon";
import {
  PLAY_STORE_URL,
  ANDROID_MIN_VERSION,
  IOS_STATUS_LABEL,
} from "@/lib/app-download";

export const metadata: Metadata = {
  title: "Download the App — MetroPaws",
  description:
    "Install the MetroPaws app on your Android phone from Google Play. Carry your pet's Digital Pet Passport, QR ID, wellness benefits, and PawPoints. The iPhone version is coming soon.",
};

const faqs = [
  {
    q: "Is this the official MetroPaws app?",
    a: "Yes. MetroPaws is published on Google Play by MetroPaws Wellness Club Philippines Inc. Installing from Google Play means you always get the reviewed, official release.",
  },
  {
    q: "Does the app cost anything?",
    a: "No. The app is free to download and free to use with your member account — your MetroPaws membership is the only thing you pay for, and it works the same whether you use the app or this website.",
  },
  {
    q: "Which Android phones can run it?",
    a: `${ANDROID_MIN_VERSION} — which covers essentially every phone in active use. If Google Play lets you install it, your phone is supported.`,
  },
  {
    q: "Will it update automatically?",
    a: "Yes. New versions arrive on their own through Google Play, like any other app. There's nothing for you to come back and re-download.",
  },
  {
    q: "I have an iPhone — when can I install it?",
    a: "The iPhone version is coming soon. We don't have a date to announce yet, and we'll let members know as soon as it's on the App Store.",
  },
  {
    q: "Do I need the app to be a member?",
    a: "No. Everything works on this website with your member account — your pets, your plan, your benefits, and your reimbursement claims. The app simply puts all of it in your pocket.",
  },
] as const;

type PlatformCardProps = {
  icon: ReactNode;
  name: string;
  tagline: string;
  points: readonly string[];
  variant?: "available" | "coming-soon";
};

function PlatformCard({
  icon,
  name,
  tagline,
  points,
  variant = "available",
}: PlatformCardProps) {
  const isComingSoon = variant === "coming-soon";

  return (
    <div
      className={[
        "flex flex-col rounded-2xl p-6",
        isComingSoon
          ? "bg-(--color-surface)/60 border border-dashed border-(--color-ink-faint)"
          : "bg-(--color-surface) border border-(--color-ink-faint)",
      ].join(" ")}
    >
      <div className="flex items-center gap-3">
        <div
          className={[
            "flex size-11 shrink-0 items-center justify-center rounded-xl",
            isComingSoon ? "bg-(--color-navy)/12" : "bg-(--color-navy)",
          ].join(" ")}
        >
          {icon}
        </div>
        <div className="min-w-0">
          <h3 className="text-sm font-bold text-(--color-navy)">{name}</h3>
          <p
            className={[
              "mt-0.5 text-xs font-semibold uppercase tracking-widest",
              isComingSoon
                ? "text-(--color-ink-muted)"
                : "text-(--color-gold)",
            ].join(" ")}
          >
            {tagline}
          </p>
        </div>
      </div>
      <ul className="mt-5 flex flex-col gap-2.5">
        {points.map((point) => (
          <li key={point} className="flex gap-2.5">
            {isComingSoon ? (
              <span
                className="mt-1.75 size-1.5 shrink-0 rounded-full bg-(--color-ink-muted)/45"
                aria-hidden="true"
              />
            ) : (
              <Check
                className="w-4 h-4 shrink-0 text-(--color-gold) mt-0.5"
                strokeWidth={2.5}
                aria-hidden="true"
              />
            )}
            <span className="text-sm leading-relaxed text-(--color-ink-muted)">
              {point}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default function DownloadPage() {
  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-col flex-1">
        {/* ── Hero ── */}
        <section className="bg-(--color-navy) py-20 md:py-28 overflow-hidden">
          <div className="max-w-6xl mx-auto px-6 lg:px-16">
            <div className="flex flex-col lg:flex-row lg:items-center gap-14 lg:gap-20">
              {/* Copy + CTA */}
              <div className="flex-1 text-center lg:text-left">
                <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold) mp-rise [animation-delay:60ms]">
                  Get the App
                </p>
                <h1 className="mt-4 text-3xl md:text-4xl lg:text-5xl font-bold tracking-tight leading-tight text-white max-w-[16ch] mx-auto lg:mx-0 mp-rise [animation-delay:180ms]">
                  Your pet&apos;s passport, in your pocket.
                </h1>
                <p className="mt-5 text-sm leading-relaxed text-white/70 max-w-[46ch] mx-auto lg:mx-0 mp-rise [animation-delay:320ms]">
                  Install MetroPaws from Google Play to carry your pet&apos;s QR
                  ID, Digital Pet Passport, wellness benefits, and PawPoints
                  everywhere. Setup takes just a few minutes.
                </p>

                <div className="mt-8 flex flex-col items-center lg:items-start gap-4 mp-rise [animation-delay:460ms]">
                  <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 w-full sm:w-auto">
                    <a
                      href={PLAY_STORE_URL}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center justify-center gap-2.5 bg-(--color-gold) text-(--color-navy) text-sm font-semibold rounded-lg px-8 py-4 transition-all duration-200 ease-out hover:brightness-105 motion-safe:hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-navy)"
                    >
                      <PlayStoreIcon />
                      Get it on Google Play
                    </a>

                    {/* Not a link: there is no App Store listing to send anyone to yet */}
                    <div className="inline-flex items-center justify-center gap-2.5 rounded-lg border border-dashed border-white/25 bg-white/6 px-8 py-4 text-sm font-semibold text-white/70">
                      <AppleLogoIcon className="text-white/70" />
                      iPhone — {IOS_STATUS_LABEL.toLowerCase()}
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center justify-center lg:justify-start gap-x-4 gap-y-1.5 text-xs text-white/55">
                    <span className="inline-flex items-center gap-1.5">
                      <ShieldCheck className="w-3.5 h-3.5 text-(--color-gold)" aria-hidden="true" />
                      Official MetroPaws app
                    </span>
                    <span aria-hidden="true" className="text-white/25">·</span>
                    <span>{ANDROID_MIN_VERSION}</span>
                    <span aria-hidden="true" className="text-white/25">·</span>
                    <span>Free</span>
                    <span aria-hidden="true" className="text-white/25">·</span>
                    <span>Updates automatically</span>
                  </div>
                </div>
              </div>

              {/* Phone + QR */}
              <div className="shrink-0 flex flex-col items-center gap-8 mp-rise [animation-delay:600ms]">
                <div className="relative w-44 md:w-52 aspect-9/19.5 rounded-4xl overflow-hidden ring-[3px] ring-(--color-gold) shadow-[0_0_48px_oklch(0.72_0.115_82/0.18)]">
                  <Image
                    src="/mobile-app-homescreen.jpg"
                    alt="The MetroPaws app home screen on a phone"
                    fill
                    sizes="(max-width: 768px) 176px, 208px"
                    className="object-cover object-top"
                    priority
                  />
                  <div className="absolute top-0 inset-x-0 h-6.5 z-10 flex items-center justify-center bg-black/80">
                    <div className="w-14 h-3.5 rounded-full bg-black" />
                  </div>
                </div>
                <div className="hidden sm:block">
                  <DownloadQr />
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* ── Platform availability ── */}
        <section className="bg-(--color-cream) py-20 md:py-28">
          <div className="max-w-5xl mx-auto px-6">
            <div className="text-center max-w-[44ch] mx-auto">
              <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
                Where to get it
              </p>
              <h2 className="mt-3 text-2xl md:text-3xl font-bold tracking-tight leading-tight text-(--color-navy)">
                Android now, iPhone next
              </h2>
              <p className="mt-4 text-sm leading-relaxed text-(--color-ink-muted)">
                MetroPaws is live on Google Play today. The iPhone version is on
                the way — and until it lands, everything works on this website.
              </p>
            </div>

            <div className="mt-12 grid gap-5 sm:grid-cols-2">
              <PlatformCard
                icon={<PlayStoreIcon />}
                name="Android"
                tagline="Available now"
                points={[
                  "Installs in one tap from Google Play",
                  "Updates arrive on their own",
                  ANDROID_MIN_VERSION,
                ]}
              />
              <PlatformCard
                icon={<AppleLogoIcon className="text-(--color-navy)/55" />}
                name="iPhone & iPad"
                tagline={IOS_STATUS_LABEL}
                variant="coming-soon"
                points={[
                  "The same MetroPaws app, built for iOS",
                  "It will arrive through the App Store",
                  "We'll tell members the moment it's live",
                ]}
              />
            </div>

            <div className="mt-12 flex items-start gap-3 rounded-2xl bg-(--color-navy) px-6 py-5 max-w-2xl mx-auto">
              <CheckCircle2 className="w-5 h-5 shrink-0 text-(--color-gold) mt-0.5" aria-hidden="true" />
              <p className="text-sm leading-relaxed text-white/85">
                Sign in with the member account you registered on this website —
                your pet&apos;s QR ID, Digital Pet Passport, wellness benefits,
                and PawPoints are all there waiting.
              </p>
            </div>
          </div>
        </section>

        {/* ── Reassurance / FAQ ── */}
        <section className="bg-(--color-surface) py-20 md:py-28 border-t border-(--color-ink-faint)">
          <div className="max-w-3xl mx-auto px-6">
            <div className="text-center">
              <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
                Good to know
              </p>
              <h2 className="mt-3 text-2xl md:text-3xl font-bold tracking-tight leading-tight text-(--color-navy)">
                Before you install
              </h2>
            </div>

            <dl className="mt-12">
              {faqs.map(({ q, a }, i) => (
                <div
                  key={q}
                  className={[
                    "py-6 border-t border-(--color-ink-faint)",
                    i === faqs.length - 1 && "border-b border-(--color-ink-faint)",
                  ]
                    .filter(Boolean)
                    .join(" ")}
                >
                  <dt className="text-sm font-bold text-(--color-navy)">{q}</dt>
                  <dd className="mt-2 text-sm leading-relaxed text-(--color-ink-muted) max-w-[65ch]">
                    {a}
                  </dd>
                </div>
              ))}
            </dl>

            <div className="mt-12 flex flex-col items-center text-center gap-4">
              <p className="flex items-center gap-2 text-sm text-(--color-ink-muted)">
                <HelpCircle className="w-4 h-4 text-(--color-gold)" aria-hidden="true" />
                Something not working? We&apos;ll sort it out with you.
              </p>
              <div className="flex flex-wrap items-center justify-center gap-3">
                <a
                  href="mailto:csr@metropaws.ph"
                  className="inline-flex items-center justify-center bg-(--color-navy) text-white text-sm font-semibold rounded-lg px-6 py-3 transition-all duration-200 ease-out hover:brightness-110 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-navy) focus-visible:ring-offset-2"
                >
                  Email csr@metropaws.ph
                </a>
                <Link
                  href="/#faq"
                  className="inline-flex items-center justify-center text-sm font-medium text-(--color-ink-muted) rounded-lg px-6 py-3 transition-colors hover:text-(--color-navy)"
                >
                  Read the full FAQ →
                </Link>
              </div>
            </div>
          </div>
        </section>
      </main>

      <SiteFooter variant="photo" />
    </div>
  );
}
