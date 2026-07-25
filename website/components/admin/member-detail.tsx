"use client";

import Link from "next/link";
import {
  ArrowLeft,
  Dog,
  Cat,
  Download,
  Mail,
  Phone,
  MapPin,
  Calendar,
} from "lucide-react";
import QRCode from "react-qr-code";
import { cn } from "@/lib/utils";
import type { Member, Pet } from "@/app/admin/(protected)/users/page";

// ── Types ─────────────────────────────────────────────────────────────────────

export interface Session {
  id: string;
  service_type: string | null;
  clinic_name: string | null;
  scheduled_at: string | null;
  completed_at: string | null;
  status: string | null;
  notes: string | null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const PLAN_COLORS: Record<string, string> = {
  Standard: "bg-[oklch(0.94_0.015_75)] text-[oklch(0.40_0.040_258)]",
  Deluxe: "bg-[oklch(0.93_0.025_80)] text-[oklch(0.40_0.060_82)]",
  Premium: "bg-[oklch(0.24_0.055_258)] text-[oklch(0.72_0.115_82)]",
};

function PlanBadge({ plan }: { plan: string | null }) {
  if (!plan) return null;
  const classes =
    PLAN_COLORS[plan] ?? "bg-[oklch(0.94_0.015_75)] text-[oklch(0.48_0.02_258)]";
  return (
    <span
      className={cn("inline-block px-2 py-0.5 rounded text-xs font-semibold", classes)}
    >
      {plan}
    </span>
  );
}

function LargeInitials({ name }: { name: string }) {
  const parts = name.trim().split(/\s+/);
  const initials =
    parts.length >= 2
      ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
      : name.slice(0, 2).toUpperCase();
  return (
    <div className="w-16 h-16 rounded-full bg-[oklch(0.32_0.050_258)] flex items-center justify-center shrink-0 ring-2 ring-[oklch(0.72_0.115_82)]/30">
      <span className="text-[oklch(0.72_0.115_82)] text-xl font-bold">{initials}</span>
    </div>
  );
}

function formatDate(iso: string): string;
function formatDate(iso: string | null): string | null;
function formatDate(iso: string | null): string | null {
  if (!iso) return null;
  return new Date(iso).toLocaleDateString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function petAge(birthYear: number | null, birthMonth: number | null): string {
  if (!birthYear) return "—";
  const now = new Date();
  let years = now.getFullYear() - birthYear;
  if (birthMonth && now.getMonth() + 1 < birthMonth) years--;
  if (years <= 0) {
    const months =
      (now.getFullYear() - birthYear) * 12 + (now.getMonth() + 1 - (birthMonth ?? 1));
    return months <= 1 ? "< 1 mo" : `${months} mo`;
  }
  return years === 1 ? "1 yr" : `${years} yrs`;
}

const SESSION_STATUS_COLORS: Record<string, string> = {
  completed: "bg-[oklch(0.93_0.040_145)] text-[oklch(0.38_0.090_145)]",
  used: "bg-[oklch(0.93_0.040_145)] text-[oklch(0.38_0.090_145)]",
  booked: "bg-[oklch(0.93_0.030_255)] text-[oklch(0.40_0.080_255)]",
  scheduled: "bg-[oklch(0.93_0.030_255)] text-[oklch(0.40_0.080_255)]",
  cancelled: "bg-[oklch(0.94_0.015_75)] text-[oklch(0.55_0.015_258)]",
};

function StatusBadge({ status }: { status: string | null }) {
  if (!status) return null;
  const classes =
    SESSION_STATUS_COLORS[status.toLowerCase()] ??
    "bg-[oklch(0.94_0.015_75)] text-[oklch(0.48_0.02_258)]";
  return (
    <span
      className={cn(
        "inline-block px-1.5 py-0.5 rounded text-[10px] font-medium capitalize shrink-0",
        classes,
      )}
    >
      {status}
    </span>
  );
}

function downloadQR(petId: string, petName: string) {
  const svgEl = document.getElementById(`pet-qr-${petId}`);
  if (!svgEl) return;
  const svgData = new XMLSerializer().serializeToString(svgEl);
  const blob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `metropaws-${petName.toLowerCase().replace(/\s+/g, "-")}-qr.svg`;
  link.click();
  URL.revokeObjectURL(url);
}

// ── Pet Card ──────────────────────────────────────────────────────────────────

function PetCard({ pet }: { pet: Pet }) {
  const PetIcon = pet.species === "cat" ? Cat : Dog;
  const qrValue = pet.id;
  const age = petAge(pet.birth_year, pet.birth_month);

  return (
    <div className="rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] overflow-hidden flex flex-col">
      {/* Header — navy */}
      <div className="bg-[oklch(0.24_0.055_258)] px-5 py-4 flex items-center justify-between gap-3">
        <div className="flex items-center gap-3 min-w-0">
          <div className="w-9 h-9 rounded-full bg-[oklch(0.32_0.050_258)] flex items-center justify-center shrink-0">
            <PetIcon size={15} className="text-[oklch(0.72_0.115_82)]" />
          </div>
          <div className="min-w-0">
            <p className="text-[oklch(0.97_0.010_80)] text-sm font-semibold truncate">
              {pet.name}
            </p>
            <p className="text-[oklch(0.60_0.010_258)] text-xs capitalize truncate">
              {[pet.species, pet.breed].filter(Boolean).join(" · ") || "—"}
            </p>
          </div>
        </div>
        <PlanBadge plan={pet.plan_type} />
      </div>

      {/* QR Code */}
      <div className="flex flex-col items-center py-7 px-5 border-b border-[oklch(0.92_0.010_258)] bg-[oklch(0.99_0.005_80)]">
        <div className="p-3 rounded-xl border border-[oklch(0.92_0.010_258)] bg-[oklch(0.99_0.005_80)]">
          <QRCode
            id={`pet-qr-${pet.id}`}
            value={qrValue}
            size={144}
            bgColor="#ffffff"
            fgColor="#0e1e3d"
            level="M"
          />
        </div>
        <p
          className="mt-3 font-mono text-[oklch(0.72_0.01_258)] tracking-widest uppercase"
          style={{ fontSize: "10px" }}
        >
          {pet.id.slice(0, 8)}
        </p>
        <button
          type="button"
          onClick={() => downloadQR(pet.id, pet.name)}
          className={cn(
            "mt-2 flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[11px]",
            "border border-[oklch(0.88_0.010_258)] text-[oklch(0.48_0.02_258)]",
            "hover:bg-[oklch(0.94_0.015_75)] hover:text-[oklch(0.24_0.055_258)]",
            "transition-colors",
          )}
        >
          <Download size={11} />
          <span>Download QR</span>
        </button>
      </div>

      {/* Bio stats */}
      <div className="px-5 py-4 grid grid-cols-3 gap-3 border-b border-[oklch(0.92_0.010_258)]">
        {[
          { label: "Age", value: age },
          { label: "Sex", value: pet.sex ?? "—", capitalize: true },
          {
            label: "Weight",
            value: pet.weight_kg != null ? `${pet.weight_kg} kg` : "—",
          },
        ].map(({ label, value, capitalize }) => (
          <div key={label}>
            <p className="text-[oklch(0.72_0.01_258)] text-[10px] font-medium uppercase tracking-wide mb-0.5">
              {label}
            </p>
            <p
              className={cn(
                "text-[oklch(0.24_0.055_258)] text-xs font-medium",
                capitalize && "capitalize",
              )}
            >
              {value}
            </p>
          </div>
        ))}
      </div>

      {/* Session Credits */}
      <div className="px-5 py-4 flex-1">
        <p className="text-[oklch(0.72_0.115_82)] text-[10px] font-semibold uppercase tracking-widest mb-3">
          Sessions Available
        </p>
        {pet.pet_services.length === 0 ? (
          <p className="text-[oklch(0.72_0.01_258)] text-xs">No sessions assigned.</p>
        ) : (
          <div className="space-y-3">
            {pet.pet_services.map((ps) => {
              const pct =
                ps.total_sessions > 0
                  ? Math.round((ps.remaining_sessions / ps.total_sessions) * 100)
                  : 0;
              const isEmpty = ps.remaining_sessions === 0;
              return (
                <div key={ps.id}>
                  <div className="flex items-center justify-between mb-1">
                    <p className="text-[oklch(0.24_0.055_258)] text-xs font-medium truncate">
                      {ps.service_type.name}
                    </p>
                    <p
                      className={cn(
                        "shrink-0 text-xs font-semibold tabular-nums",
                        isEmpty
                          ? "text-[oklch(0.55_0.12_25)]"
                          : "text-[oklch(0.24_0.055_258)]",
                      )}
                    >
                      {ps.remaining_sessions}
                      <span className="text-[oklch(0.72_0.01_258)] font-normal">
                        /{ps.total_sessions}
                      </span>
                    </p>
                  </div>
                  <div className="h-1.5 rounded-full bg-[oklch(0.92_0.010_258)] overflow-hidden">
                    <div
                      className={cn(
                        "h-full rounded-full transition-all",
                        isEmpty
                          ? "bg-[oklch(0.70_0.10_25)]"
                          : "bg-[oklch(0.72_0.115_82)]",
                      )}
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

export function MemberDetail({
  member,
  sessions,
}: {
  member: Member;
  sessions: Session[];
}) {
  const fullName = `${member.first_name} ${member.last_name}`;

  return (
    <main className="max-w-7xl mx-auto px-6 py-10">
      {/* Back nav */}
      <Link
        href="/admin/users"
        className="inline-flex items-center gap-1.5 text-[oklch(0.72_0.01_258)] hover:text-[oklch(0.24_0.055_258)] transition-colors mb-7"
        style={{ fontSize: "13px" }}
      >
        <ArrowLeft size={13} />
        Members
      </Link>

      {/* Member card — navy */}
      <div className="rounded-xl bg-[oklch(0.24_0.055_258)] px-8 py-7 mb-9 flex flex-col sm:flex-row sm:items-start gap-5">
        <LargeInitials name={fullName} />
        <div className="flex-1 min-w-0">
          <div className="flex flex-wrap items-center gap-2 mb-3">
            <h1
              className="text-[oklch(0.97_0.010_80)] font-semibold tracking-tight"
              style={{ fontSize: "22px" }}
            >
              {fullName}
            </h1>
            {member.is_founding && (
              <span className="inline-block px-2 py-0.5 rounded text-[10px] font-semibold bg-[oklch(0.72_0.115_82)]/20 text-[oklch(0.72_0.115_82)] tracking-widest uppercase">
                Founding
              </span>
            )}
          </div>
          <div className="flex flex-wrap gap-x-5 gap-y-2">
            {member.email && (
              <span
                className="flex items-center gap-1.5 text-[oklch(0.72_0.01_258)]"
                style={{ fontSize: "12px" }}
              >
                <Mail size={12} className="text-[oklch(0.60_0.070_82)] shrink-0" />
                {member.email}
              </span>
            )}
            {member.phone && (
              <span
                className="flex items-center gap-1.5 text-[oklch(0.72_0.01_258)]"
                style={{ fontSize: "12px" }}
              >
                <Phone size={12} className="text-[oklch(0.60_0.070_82)] shrink-0" />
                +63{member.phone}
              </span>
            )}
            {member.address && (
              <span
                className="flex items-center gap-1.5 text-[oklch(0.72_0.01_258)]"
                style={{ fontSize: "12px" }}
              >
                <MapPin size={12} className="text-[oklch(0.60_0.070_82)] shrink-0" />
                {member.address}
              </span>
            )}
            <span
              className="flex items-center gap-1.5 text-[oklch(0.72_0.01_258)]"
              style={{ fontSize: "12px" }}
            >
              <Calendar size={12} className="text-[oklch(0.60_0.070_82)] shrink-0" />
              Joined {formatDate(member.joined_at)}
            </span>
          </div>
        </div>

        {/* Pet count */}
        <div className="shrink-0 sm:text-right">
          <p className="text-[oklch(0.60_0.010_258)] text-[10px] uppercase tracking-widest font-medium mb-0.5">
            Pets
          </p>
          <p className="text-[oklch(0.72_0.115_82)] text-3xl font-bold leading-none">
            {member.pets.length}
          </p>
        </div>
      </div>

      {/* Pets */}
      {member.pets.length === 0 ? (
        <div className="rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] p-14 flex flex-col items-center justify-center text-center">
          <p
            className="text-[oklch(0.48_0.02_258)] font-medium"
            style={{ fontSize: "14px" }}
          >
            No pets registered
          </p>
          <p className="text-[oklch(0.72_0.01_258)] text-xs mt-1">
            Pets will appear here once the member adds them.
          </p>
        </div>
      ) : (
        <>
          <p className="text-[oklch(0.72_0.115_82)] text-xs font-semibold uppercase tracking-widest mb-5">
            Pets · {member.pets.length}
          </p>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            {member.pets.map((pet) => (
              <PetCard key={pet.id} pet={pet} />
            ))}
          </div>
        </>
      )}

      {/* Activity History */}
      <div className="mt-10">
        <p className="text-[oklch(0.72_0.115_82)] text-xs font-semibold uppercase tracking-widest mb-5">
          Activity History
        </p>
        {sessions.length === 0 ? (
          <div className="rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] px-6 py-10 text-center">
            <p className="text-[oklch(0.48_0.02_258)] text-sm">
              No activity recorded yet.
            </p>
          </div>
        ) : (
          <div className="rounded-xl border border-[oklch(0.88_0.010_258)] bg-[oklch(0.99_0.005_80)] overflow-hidden divide-y divide-[oklch(0.92_0.010_258)]">
            {sessions.map((s) => {
              const dateStr = formatDate(s.completed_at ?? s.scheduled_at);
              return (
                <div
                  key={s.id}
                  className="flex items-center justify-between gap-4 px-5 py-3.5"
                >
                  <div className="flex-1 min-w-0">
                    <p className="text-[oklch(0.24_0.055_258)] text-sm font-medium truncate">
                      {s.service_type ?? "Session"}
                    </p>
                    {s.notes && (
                      <p className="text-[oklch(0.60_0.010_258)] text-xs mt-0.5 truncate">
                        {s.notes}
                      </p>
                    )}
                  </div>
                  <div className="flex items-center gap-3 shrink-0">
                    {dateStr && (
                      <span className="text-[oklch(0.72_0.01_258)] text-xs tabular-nums">
                        {dateStr}
                      </span>
                    )}
                    <StatusBadge status={s.status} />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </main>
  );
}
