import Image from "next/image";
import { CalendarHeart, HeartHandshake, Award } from "lucide-react";

const highlights = [
  {
    icon: CalendarHeart,
    title: "Member events",
    detail: "Pet walks, wellness talks, and meetups across Las Piñas.",
  },
  {
    icon: HeartHandshake,
    title: "Wellness campaigns",
    detail: "Community drives for vaccination, deworming, and preventive care.",
  },
  {
    icon: Award,
    title: "Member recognition",
    detail: "Badges and PawPoints that celebrate responsible pet parents.",
  },
];

export function CommunitySection() {
  return (
    <section
      id="community"
      aria-labelledby="community-heading"
      className="bg-(--color-cream) py-20 md:py-28"
    >
      <div className="max-w-6xl mx-auto px-6">
        <div className="grid items-center gap-12 lg:grid-cols-2 lg:gap-20">
          {/* Copy */}
          <div className="mp-reveal">
            <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
              Community Access
            </p>
            <h2
              id="community-heading"
              className="mt-3 text-3xl md:text-5xl font-bold text-(--color-navy) tracking-tight leading-tight text-balance"
            >
              Pet parents, in good company.
            </h2>
            <p className="mt-4 text-sm text-(--color-ink-muted) leading-relaxed max-w-[52ch]">
              Membership opens the door to a local circle of pet owners who take
              care seriously, with events, campaigns, and recognition that make
              good habits worth showing off.
            </p>

            <ul className="mt-8 flex flex-col gap-6">
              {highlights.map(({ icon: Icon, title, detail }) => (
                <li key={title} className="flex gap-4">
                  <div className="mt-0.5 shrink-0">
                    <Icon
                      className="w-5 h-5 text-(--color-gold)"
                      strokeWidth={2}
                      aria-hidden="true"
                    />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-(--color-navy)">
                      {title}
                    </p>
                    <p className="mt-1 text-sm text-(--color-ink-muted) leading-relaxed">
                      {detail}
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          </div>

          {/* Image collage */}
          <div className="mp-reveal grid grid-cols-2 gap-4">
            <div className="relative col-span-2 aspect-video overflow-hidden rounded-xl">
              <Image
                src="/community-meetup.jpg"
                alt="Filipino pet owners and their dogs gathered on the grass at a Metro Manila park during golden hour"
                fill
                sizes="(max-width: 1024px) 100vw, 600px"
                className="object-cover object-center"
                loading="lazy"
              />
            </div>

            <div className="relative aspect-4/3 overflow-hidden rounded-xl">
              <Image
                src="/community-pets.jpg"
                alt="A dog and a cat resting together in the grass at golden hour"
                fill
                sizes="(max-width: 1024px) 50vw, 290px"
                className="object-cover object-center"
                loading="lazy"
              />
            </div>

            <div className="flex flex-col justify-center rounded-xl bg-(--color-navy) p-6 aspect-4/3">
              <p className="text-base font-bold leading-snug text-white">
                Better Care.
                <br />
                Happier Pets.
              </p>
              <p className="mt-2 text-xs font-medium uppercase tracking-widest text-(--color-gold)">
                MetroPaws Wellness Club
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
