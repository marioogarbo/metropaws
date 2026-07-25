"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  updatePaymentGateAction,
  updateFounding50Action,
  updateBookingEnabledAction,
  updateDirectProviderPaymentAction,
  type AppSettings,
} from "@/app/admin/(protected)/settings/actions";

interface SettingsPanelProps {
  initialSettings: AppSettings;
}

// ── Toggle switch ─────────────────────────────────────────────────────────────

interface ToggleProps {
  checked: boolean;
  onChange: (value: boolean) => void;
  disabled?: boolean;
  label: string;
}

function Toggle({ checked, onChange, disabled, label }: ToggleProps) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={cn(
        "relative inline-flex h-6 w-10 shrink-0 items-center rounded-full",
        "transition-colors duration-200 motion-reduce:transition-none",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] focus-visible:ring-offset-2",
        "disabled:cursor-not-allowed disabled:opacity-40",
        "before:absolute before:-inset-2 before:content-[''] before:rounded-full",
        checked ? "bg-[oklch(0.72_0.115_82)]" : "bg-[oklch(0.85_0.012_258)]",
      )}
    >
      <span
        className={cn(
          "pointer-events-none block h-4 w-4 rounded-full bg-[oklch(0.99_0.005_80)] shadow-sm",
          "transition-transform duration-200 motion-reduce:transition-none",
          checked ? "translate-x-5" : "translate-x-1",
        )}
      />
    </button>
  );
}

// ── Setting row ───────────────────────────────────────────────────────────────

interface SettingRowProps {
  label: string;
  description: string;
  last?: boolean;
  children: React.ReactNode;
}

function SettingRow({ label, description, last, children }: SettingRowProps) {
  return (
    <div
      className={cn(
        "flex items-start justify-between gap-8 py-5 px-6",
        !last && "border-b border-[oklch(0.91_0.008_258)]",
      )}
    >
      <div className="max-w-xs flex-1">
        <p className="text-sm text-[oklch(0.24_0.055_258)] font-semibold">{label}</p>
        <p className="text-sm text-[oklch(0.48_0.020_258)] mt-1 leading-relaxed">
          {description}
        </p>
      </div>
      <div className="shrink-0 mt-0.5">{children}</div>
    </div>
  );
}

// ── Section ───────────────────────────────────────────────────────────────────

interface SectionProps {
  title: string;
  children: React.ReactNode;
}

function Section({ title, children }: SectionProps) {
  return (
    <section>
      <p className="text-sm text-[oklch(0.48_0.020_258)] font-semibold uppercase tracking-widest mb-3">
        {title}
      </p>
      <div className="rounded-xl border border-[oklch(0.91_0.008_258)] bg-[oklch(0.99_0.005_80)] overflow-hidden">
        {children}
      </div>
    </section>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

type PendingKey = keyof AppSettings | null;

export function SettingsPanel({ initialSettings }: SettingsPanelProps) {
  const [settings, setSettings] = useState<AppSettings>(initialSettings);
  const [memberLimitInput, setMemberLimitInput] = useState(
    String(initialSettings.member_limit),
  );
  const [pendingKey, setPendingKey] = useState<PendingKey>(null);
  const [isPending, startTransition] = useTransition();

  function savePaymentGate(value: boolean) {
    const previous = settings;
    setSettings((s) => ({ ...s, require_payment: value }));
    setPendingKey("require_payment");

    startTransition(async () => {
      const result = await updatePaymentGateAction(value);
      setPendingKey(null);
      if (result.error) {
        setSettings(previous);
        toast.error(result.error);
      } else {
        toast.success("Setting saved.");
      }
    });
  }

  function saveFounding50Toggle(value: boolean) {
    const previous = settings;
    setSettings((s) => ({ ...s, founding_enrollment_active: value }));
    setPendingKey("founding_enrollment_active");

    startTransition(async () => {
      const result = await updateFounding50Action({ enabled: value }, previous);
      setPendingKey(null);
      if (result.error) {
        setSettings(previous);
        toast.error(result.error);
      } else {
        toast.success("Setting saved.");
      }
    });
  }

  function saveBookingEnabled(value: boolean) {
    const previous = settings;
    setSettings((s) => ({ ...s, booking_enabled: value }));
    setPendingKey("booking_enabled");

    startTransition(async () => {
      const result = await updateBookingEnabledAction(value);
      setPendingKey(null);
      if (result.error) {
        setSettings(previous);
        toast.error(result.error);
      } else {
        toast.success("Setting saved.");
      }
    });
  }

  function saveDirectProviderPayment(value: boolean) {
    const previous = settings;
    setSettings((s) => ({ ...s, direct_provider_payment_enabled: value }));
    setPendingKey("direct_provider_payment_enabled");

    startTransition(async () => {
      const result = await updateDirectProviderPaymentAction(value);
      setPendingKey(null);
      if (result.error) {
        setSettings(previous);
        toast.error(result.error);
      } else {
        toast.success("Setting saved.");
      }
    });
  }

  function saveMemberLimit() {
    const parsed = parseInt(memberLimitInput, 10);
    if (isNaN(parsed) || parsed < 1) {
      toast.error("Member limit must be a positive number.");
      return;
    }

    const previous = settings;
    setPendingKey("member_limit");

    startTransition(async () => {
      const result = await updateFounding50Action({ limit: parsed }, previous);
      setPendingKey(null);
      if (result.error) {
        setMemberLimitInput(String(previous.member_limit));
        toast.error(result.error);
      } else {
        setSettings((s) => ({ ...s, member_limit: parsed }));
        toast.success("Member limit saved.");
      }
    });
  }

  const memberLimitChanged = memberLimitInput !== String(settings.member_limit);

  return (
    <div className="flex flex-col gap-8">
      <Section title="Enrollment Controls">
        <SettingRow
          label="Require Payment to Activate Membership"
          description="When ON, members must complete a payment before their plan activates. When OFF, selecting a plan grants immediate full access (useful for soft launches and Founding 50 onboarding)."
        >
          <div className="flex items-center gap-2">
            <div className="w-4 flex items-center justify-center">
              {pendingKey === "require_payment" && (
                <Loader2
                  size={12}
                  className="animate-spin text-[oklch(0.48_0.020_258)]"
                />
              )}
            </div>
            <Toggle
              checked={settings.require_payment}
              onChange={savePaymentGate}
              disabled={isPending}
              label="Require Payment to Activate Membership"
            />
          </div>
        </SettingRow>

        <SettingRow
          label="Founding 50 Enrollment"
          description="When ON, the next registrants (up to the limit) are automatically marked as Founding Members and receive a bonus session of Grooming and General Consultation when they activate a plan."
          last
        >
          <div className="flex items-center gap-2">
            <div className="w-10 flex items-center justify-end gap-1.5">
              {settings.founding_claimed > 0 && (
                <span className="text-sm text-[oklch(0.48_0.020_258)] tabular-nums">
                  {settings.founding_claimed}/{settings.member_limit}
                </span>
              )}
              {pendingKey === "founding_enrollment_active" && (
                <Loader2
                  size={12}
                  className="animate-spin text-[oklch(0.48_0.020_258)]"
                />
              )}
            </div>
            <Toggle
              checked={settings.founding_enrollment_active}
              onChange={saveFounding50Toggle}
              disabled={isPending}
              label="Founding 50 Enrollment"
            />
          </div>
        </SettingRow>
      </Section>

      <Section title="Mobile App">
        <SettingRow
          label="Booking Tab"
          description="When ON, members see the Book tab and can request clinic visits. Kept OFF while there are no partner clinics — the app shows the Events tab instead. Flipping this updates every member's app without a Play Store release."
        >
          <div className="flex items-center gap-2">
            <div className="w-4 flex items-center justify-center">
              {pendingKey === "booking_enabled" && (
                <Loader2
                  size={12}
                  className="animate-spin text-[oklch(0.48_0.020_258)]"
                />
              )}
            </div>
            <Toggle
              checked={settings.booking_enabled}
              onChange={saveBookingEnabled}
              disabled={isPending}
              label="Booking Tab"
            />
          </div>
        </SettingRow>

        <SettingRow
          label="Direct-to-Provider Payments"
          description="When ON, members can ask MetroPaws to pay the clinic/groomer directly instead of reimbursing themselves, for scheduled non-emergency services only. Requires providers to be added first on the Providers page."
          last
        >
          <div className="flex items-center gap-2">
            <div className="w-4 flex items-center justify-center">
              {pendingKey === "direct_provider_payment_enabled" && (
                <Loader2
                  size={12}
                  className="animate-spin text-[oklch(0.48_0.020_258)]"
                />
              )}
            </div>
            <Toggle
              checked={settings.direct_provider_payment_enabled}
              onChange={saveDirectProviderPayment}
              disabled={isPending}
              label="Direct-to-Provider Payments"
            />
          </div>
        </SettingRow>
      </Section>

      <Section title="Enrollment Limits">
        <SettingRow
          label="Member Limit"
          description="Maximum number of members that can be enrolled. Applies to Founding Member slots when Founding 50 Enrollment is active."
          last
        >
          <div className="flex items-center gap-2">
            <input
              type="number"
              min={1}
              value={memberLimitInput}
              onChange={(e) => setMemberLimitInput(e.target.value)}
              onKeyDown={(e) =>
                e.key === "Enter" && memberLimitChanged && saveMemberLimit()
              }
              disabled={isPending}
              className={cn(
                "w-20 rounded-lg border bg-[oklch(0.97_0.010_80)] px-3 py-1.5",
                "text-sm text-[oklch(0.24_0.055_258)] font-medium text-center",
                "transition-colors duration-150 focus:outline-none focus:ring-2 focus:ring-[oklch(0.72_0.115_82)] focus:border-[oklch(0.72_0.115_82)]",
                "disabled:cursor-not-allowed disabled:opacity-40",
                "border-[oklch(0.91_0.008_258)]",
              )}
            />
            <button
              type="button"
              onClick={saveMemberLimit}
              disabled={isPending || !memberLimitChanged}
              className={cn(
                "rounded-lg px-3 py-1.5 text-sm font-semibold transition-colors duration-150",
                "bg-[oklch(0.24_0.055_258)] text-[oklch(0.97_0.010_80)]",
                "hover:bg-[oklch(0.32_0.050_258)] active:bg-[oklch(0.20_0.045_258)]",
                "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[oklch(0.72_0.115_82)] focus-visible:ring-offset-1",
                "disabled:opacity-40 disabled:cursor-not-allowed",
                "flex items-center justify-center min-w-12",
              )}
            >
              {pendingKey === "member_limit" ? (
                <Loader2 size={11} className="animate-spin" />
              ) : (
                "Save"
              )}
            </button>
          </div>
        </SettingRow>
      </Section>
    </div>
  );
}
