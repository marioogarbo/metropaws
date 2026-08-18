"use client";

import { useActionState, useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  AlertCircle,
  Eye,
  EyeOff,
  Loader2,
  Pencil,
  Plus,
  Trash2,
} from "lucide-react";
import {
  createRewardAction,
  deleteRewardAction,
  toggleRewardActiveAction,
  updateRewardAction,
  type ActionState,
  type PawReward,
} from "@/app/admin/(protected)/paw-points/actions";

const NAVY = "oklch(0.24 0.055 258)";
const MUTED = "oklch(0.48 0.020 258)";
const BORDER = "oklch(0.88 0.010 258)";
const SURFACE = "oklch(0.99 0.005 80)";
const DANGER = "oklch(0.52 0.18 25)";

const REWARD_TYPES = ["recognition", "merchandise", "credit", "voucher"];

function grouped(n: number): string {
  return n.toLocaleString("en-US");
}

function RewardForm({
  reward,
  onDone,
}: {
  reward?: PawReward;
  onDone: () => void;
}) {
  const router = useRouter();
  const action = reward ? updateRewardAction : createRewardAction;
  const [state, formAction, pending] = useActionState<ActionState, FormData>(
    action,
    { error: null },
  );
  const [attempts, setAttempts] = useState(0);

  useEffect(() => {
    if (attempts > 0 && !pending && state.error === null) {
      router.refresh();
      onDone();
    }
  }, [attempts, pending, state, router, onDone]);

  return (
    <form
      action={(formData) => {
        setAttempts((n) => n + 1);
        formAction(formData);
      }}
      className="rounded-xl border p-4 space-y-3"
      style={{ borderColor: BORDER, backgroundColor: SURFACE }}
    >
      {reward && <input type="hidden" name="id" value={reward.id} />}

      <div className="grid sm:grid-cols-[1fr_7rem] gap-3">
        <label className="flex flex-col gap-1">
          <span
            className="text-[0.6875rem] font-semibold uppercase tracking-widest"
            style={{ color: MUTED }}
          >
            Reward name
          </span>
          <input
            name="name"
            defaultValue={reward?.name}
            required
            maxLength={200}
            placeholder="MetroPaws Pet Tag, Sticker Pack or Small Merchandise Item"
            className="rounded-lg border px-3 py-1.5 text-sm"
            style={{ borderColor: BORDER, color: NAVY }}
          />
        </label>
        <label className="flex flex-col gap-1">
          <span
            className="text-[0.6875rem] font-semibold uppercase tracking-widest"
            style={{ color: MUTED }}
          >
            Points
          </span>
          <input
            name="points_required"
            type="number"
            min={1}
            step={1}
            defaultValue={reward?.points_required}
            required
            className="rounded-lg border px-3 py-1.5 text-sm tabular-nums"
            style={{ borderColor: BORDER, color: NAVY }}
          />
        </label>
      </div>

      <label className="flex flex-col gap-1">
        <span
          className="text-[0.6875rem] font-semibold uppercase tracking-widest"
          style={{ color: MUTED }}
        >
          Notes
        </span>
        <input
          name="description"
          defaultValue={reward?.description ?? ""}
          placeholder="Subject to availability."
          className="rounded-lg border px-3 py-1.5 text-sm"
          style={{ borderColor: BORDER, color: NAVY }}
        />
      </label>

      <div className="flex flex-wrap items-end gap-3">
        <label className="flex flex-col gap-1">
          <span
            className="text-[0.6875rem] font-semibold uppercase tracking-widest"
            style={{ color: MUTED }}
          >
            Type
          </span>
          <select
            name="reward_type"
            defaultValue={reward?.reward_type ?? "merchandise"}
            className="rounded-lg border px-3 py-1.5 text-sm capitalize"
            style={{ borderColor: BORDER, color: NAVY }}
          >
            {REWARD_TYPES.map((type) => (
              <option key={type} value={type}>
                {type}
              </option>
            ))}
          </select>
        </label>

        <label className="flex flex-col gap-1">
          <span
            className="text-[0.6875rem] font-semibold uppercase tracking-widest"
            style={{ color: MUTED }}
          >
            Order
          </span>
          <input
            name="sort_order"
            type="number"
            step={1}
            defaultValue={reward?.sort_order ?? 0}
            className="w-20 rounded-lg border px-3 py-1.5 text-sm tabular-nums"
            style={{ borderColor: BORDER, color: NAVY }}
          />
        </label>

        <label className="flex items-center gap-2 pb-1.5">
          <input
            type="checkbox"
            name="is_active"
            value="true"
            defaultChecked={reward?.is_active ?? true}
          />
          <span className="text-xs" style={{ color: NAVY }}>
            Visible to members
          </span>
        </label>

        <div className="flex items-center gap-2 ml-auto pb-0.5">
          <button
            type="button"
            onClick={onDone}
            className="rounded-lg px-3 py-1.5 text-sm"
            style={{ color: MUTED }}
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={pending}
            className="rounded-lg px-3 py-1.5 text-sm font-semibold text-white disabled:opacity-60 inline-flex items-center gap-1.5"
            style={{ backgroundColor: NAVY }}
          >
            {pending && <Loader2 size={13} className="animate-spin" />}
            {reward ? "Save" : "Add reward"}
          </button>
        </div>
      </div>

      {state.error && (
        <p className="text-xs flex items-center gap-1.5" style={{ color: DANGER }}>
          <AlertCircle size={13} />
          {state.error}
        </p>
      )}
    </form>
  );
}

function RewardRow({ reward }: { reward: PawReward }) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, startBusy] = useTransition();

  function run(work: () => Promise<ActionState>) {
    startBusy(async () => {
      const result = await work();
      setError(result.error);
      if (!result.error) router.refresh();
    });
  }

  const label = reward.is_active
    ? `Hide ${reward.name} from members`
    : `Show ${reward.name} to members`;

  if (editing) {
    return (
      <li className="p-3" style={{ borderColor: BORDER }}>
        <RewardForm reward={reward} onDone={() => setEditing(false)} />
      </li>
    );
  }

  return (
    <li
      className="px-4 py-3 flex items-center gap-4 border-b last:border-b-0"
      style={{ borderColor: BORDER, opacity: reward.is_active ? 1 : 0.55 }}
    >
      <span
        className="text-sm font-bold tabular-nums w-16 shrink-0"
        style={{ color: NAVY }}
      >
        {grouped(reward.points_required)}
      </span>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium truncate" style={{ color: NAVY }}>
          {reward.name}
        </p>
        <p className="text-xs truncate" style={{ color: MUTED }}>
          <span className="capitalize">{reward.reward_type}</span>
          {reward.description ? ` · ${reward.description}` : ""}
          {!reward.is_active ? " · hidden from members" : ""}
        </p>
        {error && (
          <p
            className="text-xs mt-1 flex items-center gap-1.5"
            style={{ color: DANGER }}
          >
            <AlertCircle size={12} />
            {error}
          </p>
        )}
      </div>

      <div className="flex items-center gap-1 shrink-0">
        {busy && <Loader2 size={13} className="animate-spin" style={{ color: MUTED }} />}
        <button
          type="button"
          onClick={() => run(() => toggleRewardActiveAction(reward.id, !reward.is_active))}
          title={label}
          aria-label={label}
          className="rounded-lg border p-1.5"
          style={{ borderColor: BORDER, color: MUTED }}
        >
          {reward.is_active ? <Eye size={13} /> : <EyeOff size={13} />}
        </button>
        <button
          type="button"
          onClick={() => setEditing(true)}
          title={`Edit ${reward.name}`}
          aria-label={`Edit ${reward.name}`}
          className="rounded-lg border p-1.5"
          style={{ borderColor: BORDER, color: MUTED }}
        >
          <Pencil size={13} />
        </button>
        <button
          type="button"
          onClick={() => {
            if (
              window.confirm(
                `Delete “${reward.name}”?\n\nTo retire a reward members have already seen, hide it instead — that keeps it in the catalogue.`,
              )
            ) {
              run(() => deleteRewardAction(reward.id));
            }
          }}
          title={`Delete ${reward.name}`}
          aria-label={`Delete ${reward.name}`}
          className="rounded-lg border p-1.5"
          style={{ borderColor: BORDER, color: DANGER }}
        >
          <Trash2 size={13} />
        </button>
      </div>
    </li>
  );
}

export function PawPointsRewardsTable({ rewards }: { rewards: PawReward[] }) {
  const [adding, setAdding] = useState(false);
  const activeCount = rewards.filter((r) => r.is_active).length;

  return (
    <section>
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3 mb-3">
        <div>
          <h2 className="text-sm font-semibold" style={{ color: NAVY }}>
            Rewards catalogue
          </h2>
          <p className="text-xs mt-0.5" style={{ color: MUTED }}>
            What the app shows on the member Rewards tab. {activeCount} of{" "}
            {rewards.length} visible to members.
          </p>
        </div>
        {!adding && (
          <button
            type="button"
            onClick={() => setAdding(true)}
            className="rounded-lg px-3 py-1.5 text-sm font-semibold text-white inline-flex items-center gap-1.5 self-start"
            style={{ backgroundColor: NAVY }}
          >
            <Plus size={13} />
            Add reward
          </button>
        )}
      </div>

      {adding && (
        <div className="mb-3">
          <RewardForm onDone={() => setAdding(false)} />
        </div>
      )}

      {rewards.length === 0 ? (
        <div
          className="rounded-xl border px-5 py-8 text-center"
          style={{ borderColor: BORDER, backgroundColor: SURFACE }}
        >
          <p className="text-sm font-medium" style={{ color: NAVY }}>
            The catalogue is empty
          </p>
          <p className="text-xs mt-1" style={{ color: MUTED }}>
            Members currently see “Rewards coming soon” in the app. Add the tiers
            from the Member Manual to fill it.
          </p>
        </div>
      ) : (
        <ul
          className="rounded-xl border overflow-hidden"
          style={{ borderColor: BORDER, backgroundColor: SURFACE }}
        >
          {rewards.map((reward) => (
            <RewardRow key={reward.id} reward={reward} />
          ))}
        </ul>
      )}
    </section>
  );
}
