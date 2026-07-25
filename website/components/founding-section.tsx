import Image from "next/image";
import { FoundingForm } from "@/components/founding-form";

const BACKEND_ORIGIN =
  process.env.NEXT_PUBLIC_BACKEND_URL ?? "https://metropaws-backend.onrender.com";

export function FoundingSection() {
  return (
    <section
      id="founding"
      aria-label="Founding 50 membership reservation"
      className="flex flex-col lg:flex-row"
    >
      {/* Warm up TCP/TLS before the user submits */}
      <link rel="preconnect" href={new URL(BACKEND_ORIGIN).origin} />

      <div className="flex-1 bg-(--color-navy) px-6 py-16 md:px-12 lg:px-16 xl:px-24 flex items-center justify-center lg:justify-start">
        <div className="w-full max-w-lg">
          <FoundingForm />
        </div>
      </div>

      <div className="relative hidden lg:block lg:w-[44%] xl:w-[42%] min-h-175 overflow-hidden">
        <Image
          src="/founding-50.jpg"
          alt="Limited Spots Only — The Founding 50 is an exclusive, by-invitation membership"
          fill
          sizes="(max-width: 1280px) 44vw, 42vw"
          className="object-cover object-left"
        />
      </div>
    </section>
  );
}
