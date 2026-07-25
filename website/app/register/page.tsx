import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { RegisterForm } from "@/components/register-form";

export const metadata: Metadata = {
  title: "Create Account — MetroPaws",
  description:
    "Join MetroPaws Wellness Club and give your pet the care they deserve. Free to register.",
};

export default function RegisterPage() {
  return (
    <main className="flex min-h-screen flex-col lg:flex-row">
      {/* ── Left: form panel ── */}
      <div className="flex flex-1 flex-col bg-(--color-cream)">
        <header className="flex shrink-0 items-center justify-between px-8 pb-4 pt-7">
          <Link href="/" aria-label="Back to MetroPaws homepage">
            <Image
              src="/logo-full.png"
              alt="MetroPaws"
              width={148}
              height={38}
              priority
            />
          </Link>
          <Link
            href="/"
            className="text-sm text-(--color-ink-muted) transition-colors duration-150 hover:text-(--color-ink)"
          >
            Back to home
          </Link>
        </header>

        <div className="flex flex-1 items-center justify-center px-8 py-10">
          <div className="mp-rise w-full max-w-[400px]">
            <RegisterForm />
          </div>
        </div>
      </div>

      {/* ── Right: brand hero panel (desktop only) ── */}
      <div
        className="relative hidden overflow-hidden lg:sticky lg:top-0 lg:block lg:h-screen lg:w-[42%]"
        aria-hidden="true"
      >
        <Image
          src="/pet-care-register.jpg"
          alt=""
          fill
          sizes="42vw"
          priority
          className="object-cover object-center"
        />
        <div
          className="absolute inset-0"
          style={{
            background:
              "linear-gradient(175deg, oklch(0.24 0.055 258 / 0.28) 0%, oklch(0.24 0.055 258 / 0.52) 42%, oklch(0.24 0.055 258 / 0.87) 76%, oklch(0.24 0.055 258 / 0.97) 100%)",
          }}
        />
        <div className="absolute inset-0 z-10 flex flex-col justify-end px-10 pb-14">
          <p className="mb-4 text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
            MetroPaws
          </p>
          <h2 className="mb-4 max-w-[22ch] text-3xl font-bold leading-tight tracking-tight text-[oklch(0.98_0.005_80)] xl:text-4xl">
            One QR code. Every visit. No paperwork.
          </h2>
          <p className="max-w-[36ch] text-sm leading-relaxed text-[oklch(0.98_0.005_80/0.65)]">
            Your pet&apos;s full health profile, vaccination records, and service history.
            Ready at any partner clinic, always.
          </p>
        </div>
      </div>
    </main>
  );
}
