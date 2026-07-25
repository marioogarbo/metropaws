import { Sparkles, RefreshCw, UserPlus, CheckCircle2, Cake } from "lucide-react";

const earnActions = [
  { icon: Sparkles, label: "Activate your membership", points: "100" },
  { icon: RefreshCw, label: "Renew each year", points: "150" },
  { icon: UserPlus, label: "Refer a fellow pet parent", points: "100" },
  { icon: CheckCircle2, label: "Complete an approved claim", points: "20" },
  { icon: Cake, label: "Your pet's birthday", points: "20" },
];

const rewardLadder = [
  { points: "250", reward: "Responsible Fur Parent digital badge" },
  { points: "1,000", reward: "MetroPaws Pet ID tag" },
  { points: "2,000", reward: "Vet consultation cashback booster" },
  { points: "5,000", reward: "Annual wellness credit booster" },
  { points: "10,000", reward: "Founder Circle recognition package", elite: true },
];

export function PawPointsSection() {
  return (
    <section
      id="pawpoints"
      aria-labelledby="pawpoints-heading"
      className="bg-(--color-navy) py-20 md:py-28"
    >
      <div className="max-w-6xl mx-auto px-6">
        <div className="mp-reveal max-w-2xl">
          <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
            PawPoints Rewards
          </p>
          <h2
            id="pawpoints-heading"
            className="mt-3 text-3xl md:text-5xl font-bold text-white tracking-tight leading-tight text-balance"
          >
            Caring for your pet earns its keep.
          </h2>
          <p className="mt-4 text-sm text-white/60 leading-relaxed max-w-[58ch]">
            PawPoints reward the everyday habits of a responsible pet parent.
            Earn as you join, renew, refer, and keep up with wellness, then
            redeem for member perks.
          </p>
        </div>

        <div className="mt-14 grid gap-12 lg:grid-cols-2 lg:gap-20">
          {/* Earn */}
          <div className="mp-reveal">
            <h3 className="text-base font-semibold text-white">
              Ways to earn
            </h3>
            <ul className="mt-6 flex flex-col divide-y divide-white/10">
              {earnActions.map(({ icon: Icon, label, points }) => (
                <li
                  key={label}
                  className="flex items-center gap-4 py-3.5"
                >
                  <Icon
                    className="w-4 h-4 text-(--color-gold) shrink-0"
                    strokeWidth={2}
                    aria-hidden="true"
                  />
                  <span className="text-sm text-white/85 flex-1">{label}</span>
                  <span className="text-sm font-semibold text-(--color-gold) tabular-nums whitespace-nowrap">
                    +{points}
                  </span>
                </li>
              ))}
            </ul>
            <p className="mt-5 text-xs text-white/60 leading-relaxed">
              Points shown at Standard rate. Deluxe and Premium members earn up
              to 4&times; faster.
            </p>
          </div>

          {/* Redeem ladder */}
          <div className="mp-reveal">
            <h3 className="text-base font-semibold text-white">
              What you can redeem
            </h3>
            <ol className="mt-6 flex flex-col gap-3">
              {rewardLadder.map(({ points, reward, elite }) => (
                <li
                  key={points}
                  className={[
                    "flex items-center gap-4 rounded-lg px-5 py-4",
                    elite
                      ? "bg-(--color-gold) text-(--color-navy)"
                      : "bg-(--color-navy-mid)",
                  ].join(" ")}
                >
                  <span
                    className={[
                      "text-xl font-bold tabular-nums shrink-0 w-20",
                      elite ? "text-(--color-navy)" : "text-(--color-gold)",
                    ].join(" ")}
                  >
                    {points}
                  </span>
                  <span
                    className={[
                      "text-sm font-medium",
                      elite ? "text-(--color-navy)" : "text-white/85",
                    ].join(" ")}
                  >
                    {reward}
                  </span>
                </li>
              ))}
            </ol>
          </div>
        </div>

        <p className="mp-reveal mt-12 text-xs text-white/60 leading-relaxed max-w-[72ch]">
          PawPoints are loyalty points, not cash, and are redeemed under approved
          reward rules. The rewards catalogue may change with availability and
          program updates.
        </p>
      </div>
    </section>
  );
}
