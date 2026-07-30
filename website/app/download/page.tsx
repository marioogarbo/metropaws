import type { Metadata } from "next";
import type { ReactNode } from "react";
import Image from "next/image";
import Link from "next/link";
import {
  Download,
  ShieldCheck,
  FolderDown,
  Settings2,
  PackageCheck,
  CheckCircle2,
  Apple,
  HelpCircle,
  Check,
  TriangleAlert,
} from "lucide-react";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { DownloadQr } from "@/components/download-qr";
import { PlayStoreIcon } from "@/components/play-store-icon";
import {
  PLAY_STORE_URL,
  APK_HREF,
  APK_VERSION,
  ANDROID_MIN_VERSION,
} from "@/lib/app-download";

export const metadata: Metadata = {
  title: "Download the App — MetroPaws",
  description:
    "Install the MetroPaws app on your Android phone from Google Play or straight from us. Get your pet's Digital Pet Passport, QR ID, wellness benefits, and PawPoints.",
};

const steps = [
  {
    icon: Download,
    title: "Download the APK",
    body: "Tap the download button above. The MetroPaws app file (.apk) saves to your phone — it's about the size of any normal app.",
  },
  {
    icon: FolderDown,
    title: "Open the file",
    body: "Tap the download when it finishes — from your notification bar, or in your Downloads folder / Files app.",
  },
  {
    icon: Settings2,
    title: 'Allow "this source" once',
    body: 'Android asks permission the first time. Tap Settings, switch on "Allow from this source," then go back — you only do this once.',
  },
  {
    icon: PackageCheck,
    title: "Tap Install",
    body: 'If Play Protect shows a notice, tap "Install anyway" or "More details → Install." This is our official app — the notice is just standard for apps outside the Play Store.',
  },
] as const;

const faqs = [
  {
    q: "Which one should I choose?",
    a: "Google Play if you want the simplest install and automatic updates — that suits most members. The direct download if you want new features as soon as they're ready, before the Google Play version catches up. Both are the same official app.",
  },
  {
    q: "Is this safe to install?",
    a: "Yes. MetroPaws is published on Google Play by MetroPaws Wellness Club Philippines Inc. The direct download is that same official app, built and signed by us — it just runs a little ahead of the Google Play release.",
  },
  {
    q: "Why does my phone show a warning?",
    a: 'Android shows a standard caution for any app installed outside the Play Store — it appears for every app delivered this way, not because anything is wrong. Tapping "Install anyway" is expected here. Installing from Google Play skips this step entirely.',
  },
  {
    q: "Will it update automatically?",
    a: "From Google Play, yes — updates install on their own like any other app. With the direct download, come back to this page and download the newest version whenever we let you know one is ready.",
  },
  {
    q: "Can I switch between the two later?",
    a: "Yes, but uninstall the one you have first, then install the other. Android will not install over an app that came from a different source. Nothing important is lost — your pets, membership, and PawPoints live on your account and come straight back when you sign in.",
  },
  {
    q: "I have an iPhone — can I install it?",
    a: "Not yet. The iPhone version is on the way. In the meantime you can use everything on the website with your member account.",
  },
] as const;

type InstallRouteProps = {
  icon: ReactNode;
  name: string;
  tagline: string;
  points: readonly string[];
};

function InstallRoute({ icon, name, tagline, points }: InstallRouteProps) {
  return (
    <div className="flex flex-col rounded-2xl bg-(--color-surface) border border-(--color-ink-faint) p-6">
      <div className="flex items-center gap-3">
        <div className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-(--color-navy)">
          {icon}
        </div>
        <div className="min-w-0">
          <h3 className="text-sm font-bold text-(--color-navy)">{name}</h3>
          <p className="mt-0.5 text-xs font-semibold uppercase tracking-widest text-(--color-gold)">
            {tagline}
          </p>
        </div>
      </div>
      <ul className="mt-5 flex flex-col gap-2.5">
        {points.map((point) => (
          <li key={point} className="flex gap-2.5">
            <Check
              className="w-4 h-4 shrink-0 text-(--color-gold) mt-0.5"
              strokeWidth={2.5}
              aria-hidden="true"
            />
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
                  Install MetroPaws on your Android phone to carry your pet&apos;s
                  QR ID, Digital Pet Passport, wellness benefits, and PawPoints
                  everywhere. Setup takes just a few minutes.
                </p>

                <div className="mt-8 flex flex-col items-center lg:items-start gap-4 mp-rise [animation-delay:460ms]">
                  <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 w-full sm:w-auto">
                    <a
                      href={APK_HREF}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center justify-center gap-2.5 bg-(--color-gold) text-(--color-navy) text-sm font-semibold rounded-lg px-8 py-4 transition-all duration-200 ease-out hover:brightness-105 motion-safe:hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-navy)"
                    >
                      <Download className="w-4.5 h-4.5" strokeWidth={2.5} aria-hidden="true" />
                      Download for Android
                    </a>

                    <a
                      href={PLAY_STORE_URL}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center justify-center gap-2.5 bg-white/8 border border-white/20 text-white text-sm font-semibold rounded-lg px-8 py-4 transition-all duration-200 ease-out hover:bg-white/14 hover:border-white/35 motion-safe:hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-navy)"
                    >
                      <PlayStoreIcon />
                      Get it on Google Play
                    </a>
                  </div>

                  <div className="flex flex-wrap items-center justify-center lg:justify-start gap-x-4 gap-y-1.5 text-xs text-white/55">
                    <span className="inline-flex items-center gap-1.5">
                      <ShieldCheck className="w-3.5 h-3.5 text-(--color-gold)" aria-hidden="true" />
                      Official MetroPaws app
                    </span>
                    <span aria-hidden="true" className="text-white/25">·</span>
                    <span>Direct download v{APK_VERSION}</span>
                    <span aria-hidden="true" className="text-white/25">·</span>
                    <span>{ANDROID_MIN_VERSION}</span>
                    <span aria-hidden="true" className="text-white/25">·</span>
                    <span>Free</span>
                  </div>

                  <p className="flex items-start gap-2.5 rounded-xl border border-(--color-gold)/35 bg-(--color-gold)/8 px-4 py-3 text-xs leading-relaxed text-white/80 max-w-[52ch] text-left">
                    <TriangleAlert
                      className="w-4 h-4 shrink-0 text-(--color-gold) mt-px"
                      aria-hidden="true"
                    />
                    <span>
                      <strong className="font-semibold text-white">
                        Already have MetroPaws on your phone?
                      </strong>{" "}
                      These two versions can&apos;t replace each other. Uninstall
                      the one you have before installing the other, or Android
                      will refuse it.
                    </span>
                  </p>

                  <p className="flex items-center gap-2 text-xs text-white/45">
                    <Apple className="w-3.5 h-3.5" aria-hidden="true" />
                    iPhone version coming soon · Now live on Google Play
                  </p>
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

        {/* ── Choosing a route, then the direct-install steps ── */}
        <section className="bg-(--color-cream) py-20 md:py-28">
          <div className="max-w-5xl mx-auto px-6">
            <div className="text-center max-w-[44ch] mx-auto">
              <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
                How to install
              </p>
              <h2 className="mt-3 text-2xl md:text-3xl font-bold tracking-tight leading-tight text-(--color-navy)">
                Two ways in — pick one
              </h2>
              <p className="mt-4 text-sm leading-relaxed text-(--color-ink-muted)">
                Both are the official MetroPaws app. Choose the one that suits
                you and stay with it — switching later means uninstalling first.
              </p>
            </div>

            <div className="mt-12 grid gap-5 sm:grid-cols-2">
              <InstallRoute
                icon={<PlayStoreIcon />}
                name="Google Play"
                tagline="Simplest"
                points={[
                  "Installs in one tap, no extra permissions",
                  "Updates arrive on their own",
                  "Distributed and checked by Google",
                ]}
              />
              <InstallRoute
                icon={
                  <Download
                    className="w-5 h-5 text-(--color-gold)"
                    strokeWidth={2}
                    aria-hidden="true"
                  />
                }
                name="Direct download"
                tagline="Newest first"
                points={[
                  "New features land here before Google Play",
                  'Needs a one-time "allow from this source" tap',
                  "Revisit this page to get each update",
                ]}
              />
            </div>

            <div className="mt-16 text-center max-w-[44ch] mx-auto">
              <h3 className="text-xl md:text-2xl font-bold tracking-tight leading-tight text-(--color-navy)">
                Installing the direct download
              </h3>
              <p className="mt-3 text-sm leading-relaxed text-(--color-ink-muted)">
                Google Play installs the way any app does, so nothing below
                applies there. Downloading straight from us takes four taps —
                here&apos;s exactly what to press.
              </p>
            </div>

            <ol className="mt-12 grid gap-5 sm:grid-cols-2">
              {steps.map(({ icon: Icon, title, body }, i) => (
                <li
                  key={title}
                  className="relative flex gap-4 rounded-2xl bg-(--color-surface) border border-(--color-ink-faint) p-6"
                >
                  <div className="shrink-0">
                    <div className="flex size-11 items-center justify-center rounded-xl bg-(--color-navy)">
                      <Icon className="w-5 h-5 text-(--color-gold)" strokeWidth={2} aria-hidden="true" />
                    </div>
                  </div>
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-bold uppercase tracking-widest text-(--color-gold)">
                        Step {i + 1}
                      </span>
                    </div>
                    <h3 className="mt-1 text-sm font-bold text-(--color-navy)">
                      {title}
                    </h3>
                    <p className="mt-1.5 text-sm leading-relaxed text-(--color-ink-muted)">
                      {body}
                    </p>
                  </div>
                </li>
              ))}
            </ol>

            <div className="mt-8 flex items-start gap-3 rounded-2xl bg-(--color-navy) px-6 py-5 max-w-2xl mx-auto">
              <CheckCircle2 className="w-5 h-5 shrink-0 text-(--color-gold) mt-0.5" aria-hidden="true" />
              <p className="text-sm leading-relaxed text-white/85">
                That&apos;s it — open MetroPaws and sign in with the member
                account you registered on this website. Your pets and benefits
                are waiting.
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
                Stuck on any step? We&apos;ll walk you through it.
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
