"use client";

import { useState, useTransition } from "react";
import { Loader2, ShieldCheck } from "lucide-react";
import { cn } from "@/lib/utils";
import { updateMemberDirectPayAction } from "@/app/admin/(protected)/users/[id]/actions";

/**
 * Per-member override of the global Direct-to-Provider Payments setting.
 *
 * Exists because the global switch is all-or-nothing: one member misusing the
 * flow used to mean turning it off for everybody. This is the Membership
 * Agreement's "Authorization Restricted" status (§5.7), with §17 supplying the
 * grounds — so the reason is captured alongside the setting, not just the flag.
 */

type Choice = "inherit" | "on" | "off";

const CHOICES: { value: Choice; label: string; hint: string }[] = [
  { value: "inherit", label: "Follow global", hint: "Uses the Settings page switch" },
  { value: "on", label: "Always on", hint: "Allowed even if the global switch is off" },
  { value: "off", label: "Restricted", hint: "Blocked even if the global switch is on" },
];

function toChoice(enabled: boolean | null | undefined): Choice {
  if (enabled === true) return "on";
  if (enabled === false) return "off";
  return "inherit";
}

function toEnabled(choice: Choice): boolean | null {
  if (choice === "on") return true;
  if (choice === "off") return false;
  return null;
}

export function MemberDirectPayControl({
  memberId,
  directPayEnabled,
  directPayNote,
  directPayUpdatedAt,
}: {
  memberId: string;
  directPayEnabled: boolean | null | undefined;
  directPayNote: string | null | undefined;
  directPayUpdatedAt: string | null | undefined;
}) {
  const [choice, setChoice] = useState<Choice>(toChoice(directPayEnabled));
  const [note, setNote] = useState(directPayNote ?? "");
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [isPending, startTransition] = useTransition();

  const savedChoice = toChoice(directPayEnabled);
  const dirty = choice !== savedChoice || note.trim() !== (directPayNote ?? "").trim();

  function save() {
    setError(null);
    setSaved(false);
    startTransition(async () => {
      const result = await updateMemberDirectPayAction(memberId, toEnabled(choice), note);
      if (result.error) {
        setError(result.error);
        return;
      }
      setSaved(true);
    });
  }

  return (
    <section className="rounded-xl border border-[oklch(0.90_0.010_258)] bg-white p-5">
      <div className="mb-1 flex items-center gap-2">
        <ShieldCheck size={15} className="text-[oklch(0.48_0.020_258)]" />
        <h2 className="text-sm font-semibold text-[oklch(0.24_0.055_258)]">
          Direct-to-Provider Payments
        </h2>
      </div>
      <p className="mb-4 text-sm text-[oklch(0.48_0.020_258)]">
        Whether this member may ask MetroPaws to pay a provider directly instead of
        reimbursing themselves. Restricting one member leaves the feature on for
        everyone else.
      </p>

      <div
        role="radiogroup"
        aria-label="Direct-to-provider access for this member"
        className="flex flex-col gap-1.5 sm:flex-row"
      >
        {CHOICES.map((option) => {
          const active = choice === option.value;
          return (
            <button
              key={option.value}
              type="button"
              role="radio"
              aria-checked={active}
              disabled={isPending}
              onClick={() => {
                setChoice(option.value);
                setSaved(false);
              }}
              className={cn(
                "flex-1 rounded-lg border px-3 py-2.5 text-left transition-colors duration-150",
                "disabled:cursor-not-allowed disabled:opacity-60",
                active
                  ? "border-[oklch(0.24_0.055_258)] bg-[oklch(0.24_0.055_258)] text-white"
                  : "border-[oklch(0.90_0.010_258)] bg-[oklch(0.97_0.010_80)] text-[oklch(0.24_0.055_258)] hover:border-[oklch(0.72_0.115_82)]",
              )}
            >
              <span className="block text-sm font-medium">{option.label}</span>
              <span
                className={cn(
                  "mt-0.5 block text-xs",
                  active ? "text-white/70" : "text-[oklch(0.48_0.020_258)]",
                )}
              >
                {option.hint}
              </span>
            </button>
          );
        })}
      </div>

      <label className="mt-4 block">
        <span className="mb-1.5 block text-xs font-medium text-[oklch(0.48_0.020_258)]">
          Reason {choice === "off" && <span aria-hidden="true">— recommended</span>}
        </span>
        <input
          type="text"
          value={note}
          disabled={isPending}
          onChange={(e) => {
            setNote(e.target.value);
            setSaved(false);
          }}
          placeholder="e.g. repeated no-shows, ref #1043"
          className="w-full rounded-lg border border-[oklch(0.90_0.010_258)] bg-[oklch(0.97_0.010_80)] px-3 py-2 text-sm text-[oklch(0.24_0.055_258)] placeholder:text-[oklch(0.68_0.015_258)] focus:border-transparent focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] disabled:opacity-60"
        />
      </label>

      <div className="mt-4 flex items-center gap-3">
        <button
          type="button"
          onClick={save}
          disabled={isPending || !dirty}
          className="inline-flex items-center gap-2 rounded-lg bg-[oklch(0.24_0.055_258)] px-4 py-2 text-sm font-medium text-white transition-opacity duration-150 hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {isPending && <Loader2 size={13} className="animate-spin" />}
          Save
        </button>
        {error && (
          <p role="alert" className="text-sm text-red-600">
            {error}
          </p>
        )}
        {!error && saved && !dirty && (
          <p className="text-sm text-[oklch(0.48_0.020_258)]">Saved.</p>
        )}
        {!error && !saved && directPayUpdatedAt && (
          <p className="text-sm text-[oklch(0.48_0.020_258)]">
            Last changed{" "}
            {new Date(directPayUpdatedAt).toLocaleDateString("en-PH", {
              day: "numeric",
              month: "short",
              year: "numeric",
            })}
          </p>
        )}
      </div>
    </section>
  );
}
