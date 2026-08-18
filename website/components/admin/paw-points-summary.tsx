import { Coins, TrendingUp, Wallet, Users } from "lucide-react";
import type { PawPointsSummary } from "@/app/admin/(protected)/paw-points/actions";

const NAVY = "oklch(0.24 0.055 258)";
const MUTED = "oklch(0.48 0.020 258)";
const BORDER = "oklch(0.88 0.010 258)";
const SURFACE = "oklch(0.99 0.005 80)";

function grouped(n: number): string {
  return n.toLocaleString("en-US");
}

function Tile({
  label,
  value,
  sub,
  icon,
}: {
  label: string;
  value: number;
  sub: string;
  icon: React.ReactNode;
}) {
  return (
    <div
      className="rounded-xl border px-5 py-4"
      style={{ backgroundColor: SURFACE, borderColor: BORDER }}
    >
      <div className="flex items-center gap-2 mb-2" style={{ color: MUTED }}>
        {icon}
        <p className="text-[0.6875rem] font-semibold uppercase tracking-widest">
          {label}
        </p>
      </div>
      <p
        className="text-2xl font-bold tracking-tight tabular-nums"
        style={{ color: NAVY }}
      >
        {grouped(value)}
      </p>
      <p className="text-xs mt-1" style={{ color: MUTED }}>
        {sub}
      </p>
    </div>
  );
}

export function PawPointsSummaryPanel({ summary }: { summary: PawPointsSummary }) {
  const { top_earners: topEarners, reward_reach: rewardReach } = summary;

  return (
    <section className="space-y-6">
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <Tile
          label="Issued"
          value={summary.total_issued}
          sub="Points ever earned"
          icon={<TrendingUp size={13} />}
        />
        <Tile
          label="Redeemed"
          value={summary.total_redeemed}
          sub="Spent on rewards"
          icon={<Coins size={13} />}
        />
        <Tile
          label="Outstanding"
          value={summary.total_outstanding}
          sub="Held by members now"
          icon={<Wallet size={13} />}
        />
        <Tile
          label="Holders"
          value={summary.members_with_points}
          sub="Members with a balance"
          icon={<Users size={13} />}
        />
      </div>

      {summary.total_issued > 0 && summary.total_redeemed === 0 && (
        <p
          className="text-xs rounded-lg border px-4 py-3"
          style={{
            color: MUTED,
            borderColor: BORDER,
            backgroundColor: "oklch(0.97 0.01 80)",
          }}
        >
          Redeemed reads zero because members have no way to claim a reward yet —
          the app shows the catalogue but has no Redeem action. Every point issued
          so far is still outstanding.
        </p>
      )}

      <div className="grid lg:grid-cols-2 gap-6">
        <div>
          <h2
            className="text-sm font-semibold mb-1"
            style={{ color: NAVY }}
          >
            Who can claim what
          </h2>
          <p className="text-xs mb-3" style={{ color: MUTED }}>
            Members whose balance already covers each reward. The catalogue holds
            no cost per reward, so this is the real exposure figure rather than an
            invented peso total.
          </p>
          {rewardReach.length === 0 ? (
            <p
              className="text-xs rounded-lg border px-4 py-3"
              style={{ color: MUTED, borderColor: BORDER, backgroundColor: SURFACE }}
            >
              No active rewards in the catalogue.
            </p>
          ) : (
            <ul
              className="rounded-xl border divide-y overflow-hidden"
              style={{ borderColor: BORDER, backgroundColor: SURFACE }}
            >
              {rewardReach.map((reward) => (
                <li
                  key={reward.reward_id}
                  className="px-4 py-2.5 flex items-center justify-between gap-4"
                  style={{ borderColor: BORDER }}
                >
                  <div className="min-w-0">
                    <p
                      className="text-xs font-medium truncate"
                      style={{ color: NAVY }}
                    >
                      {reward.name}
                    </p>
                    <p className="text-[0.6875rem]" style={{ color: MUTED }}>
                      {grouped(reward.points_required)} pts
                    </p>
                  </div>
                  <span
                    className="text-xs font-semibold tabular-nums shrink-0"
                    style={{ color: reward.members_eligible > 0 ? NAVY : MUTED }}
                  >
                    {reward.members_eligible}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div>
          <h2 className="text-sm font-semibold mb-1" style={{ color: NAVY }}>
            Top earners
          </h2>
          <p className="text-xs mb-3" style={{ color: MUTED }}>
            Ranked by lifetime earned, which never decreases — so redeeming does
            not cost a member their place.
          </p>
          {topEarners.length === 0 ? (
            <p
              className="text-xs rounded-lg border px-4 py-3"
              style={{ color: MUTED, borderColor: BORDER, backgroundColor: SURFACE }}
            >
              No points awarded yet.
            </p>
          ) : (
            <ol
              className="rounded-xl border divide-y overflow-hidden"
              style={{ borderColor: BORDER, backgroundColor: SURFACE }}
            >
              {topEarners.map((earner, i) => (
                <li
                  key={earner.member_id}
                  className="px-4 py-2.5 flex items-center justify-between gap-4"
                  style={{ borderColor: BORDER }}
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <span
                      className="text-[0.6875rem] font-semibold tabular-nums w-4 shrink-0"
                      style={{ color: MUTED }}
                    >
                      {i + 1}
                    </span>
                    <p
                      className="text-xs font-medium truncate"
                      style={{ color: NAVY }}
                    >
                      {earner.first_name} {earner.last_name}
                    </p>
                  </div>
                  <span
                    className="text-xs tabular-nums shrink-0"
                    style={{ color: MUTED }}
                  >
                    {grouped(earner.lifetime_earned)} earned ·{" "}
                    <strong style={{ color: NAVY }}>
                      {grouped(earner.current_balance)}
                    </strong>{" "}
                    held
                  </span>
                </li>
              ))}
            </ol>
          )}
        </div>
      </div>
    </section>
  );
}
