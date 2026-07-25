import Image from "next/image";
import Link from "next/link";
import { AppStoreButtons } from "@/components/app-store-buttons";

export function HeroSection() {
  return (
    <section className="relative flex-1 min-h-155 overflow-hidden">
      <Image
        src="/hero-owner.jpg"
        alt="A Filipino pet owner with his golden retriever in a sunlit Metro Manila garden"
        fill
        className="object-cover object-[70%_center] lg:object-center"
        priority
      />
      {/* Mobile: bottom-up scrim keeps the bottom-anchored text legible over the subject */}
      <div className="absolute inset-0 min-[500px]:hidden bg-linear-to-t from-(--color-navy)/92 from-15% via-(--color-navy)/55 to-(--color-navy)/20" />
      {/* Desktop: left-right scrim for the left-aligned, vertically centered text */}
      <div className="absolute inset-0 hidden min-[500px]:block bg-linear-to-r from-(--color-navy)/70 via-(--color-navy)/45 to-(--color-navy)/10" />

      <div className="absolute inset-0 z-10 flex items-end min-[500px]:items-center">
        <div className="w-full px-6 pb-14 min-[500px]:pb-0 min-[500px]:px-16 xl:px-24 flex flex-col items-center text-center min-[500px]:items-start min-[500px]:text-left">
          <h1 className="text-5xl lg:text-6xl font-bold leading-tight tracking-tight">
            <span className="block text-white mp-rise [animation-delay:80ms]">
              Pet Wellness
            </span>
            <span className="block text-(--color-gold) mp-rise [animation-delay:220ms]">
              Shouldn&apos;t be
            </span>
            <span className="block text-white mp-rise [animation-delay:360ms]">
              a Gamble.
            </span>
          </h1>

          <p className="text-white/85 text-sm leading-relaxed mt-4 max-w-[42ch] mp-rise [animation-delay:520ms]">
            Your pet&apos;s Digital Pet Passport, wellness benefits, and PawPoints
            rewards in one place. Free to register, always in your pocket.
          </p>

          <div className="mt-10 min-[500px]:mt-8 w-full min-[500px]:w-auto mp-rise [animation-delay:660ms]">
            <Link
              href="#founding"
              className="inline-flex items-center justify-center w-full lg:w-auto bg-(--color-gold) text-(--color-navy) text-sm font-semibold rounded-lg px-8 py-4 transition-all duration-200 ease-out hover:brightness-105 motion-safe:hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-navy)"
            >
              Reserve Your Founding Spot →
            </Link>
            <div className="mt-3 flex justify-center min-[500px]:justify-start">
              <Link
                href="/register"
                className="text-xs text-white/70 hover:text-white transition-colors"
              >
                or create an account
              </Link>
            </div>
          </div>

          <div className="mt-4 mp-rise [animation-delay:820ms]">
            <AppStoreButtons />
          </div>
        </div>
      </div>
    </section>
  );
}
