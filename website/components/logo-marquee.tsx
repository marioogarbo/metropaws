import Image from "next/image";

const LOGOS_PER_GROUP = 10;

export function LogoMarquee() {
  const slots = Array.from({ length: LOGOS_PER_GROUP });

  return (
    <div
      aria-hidden="true"
      className="relative overflow-hidden select-none py-5 md:py-8 bg-(--color-navy)"
      style={{
        borderTop: "1px solid oklch(0.72 0.115 82 / 0.30)",
        borderBottom: "1px solid oklch(0.72 0.115 82 / 0.30)",
      }}
    >
      {/* Left edge fade */}
      <div
        className="absolute inset-y-0 left-0 w-12 md:w-32 z-10 pointer-events-none"
        style={{
          background: "linear-gradient(to right, oklch(0.24 0.055 258), transparent)",
        }}
      />
      {/* Right edge fade */}
      <div
        className="absolute inset-y-0 right-0 w-12 md:w-32 z-10 pointer-events-none"
        style={{
          background: "linear-gradient(to left, oklch(0.24 0.055 258), transparent)",
        }}
      />

      {/* Doubled track — second group creates seamless loop */}
      <div
        className="mp-marquee-track flex items-center"
        style={{ width: "max-content" }}
      >
        {[...slots, ...slots].map((_, i) => (
          <div key={i} className="flex items-center">
            <div className="px-5 md:px-10">
              <Image
                src="/logo-full-white-metro.png"
                alt=""
                width={160}
                height={44}
                className="h-6 md:h-9 w-auto opacity-50"
              />
            </div>
            {/* Gold separator dot */}
            <div
              className="shrink-0 w-1 h-1 rounded-full"
              style={{ backgroundColor: "oklch(0.72 0.115 82 / 0.55)" }}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
