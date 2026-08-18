"use client";

import { useActionState, useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  AlertCircle,
  ChevronDown,
  Coins,
  Loader2,
  Plus,
  Search,
  X,
} from "lucide-react";
import {
  awardPointsAction,
  fetchMemberBalancesAction,
  fetchMemberLedgerAction,
  type LedgerEntry,
  type MemberBalance,
  type MemberLedger,
} from "@/app/admin/(protected)/paw-points/actions";

const NAVY = "oklch(0.24 0.055 258)";
const MUTED = "oklch(0.48 0.020 258)";
const BORDER = "oklch(0.88 0.010 258)";
const SURFACE = "oklch(0.99 0.005 80)";

const ACTIVITY_LABELS: Record<string, string> = {
  membership_activation: "Membership activation",
  membership_renewal: "Membership renewal",
  pet_profile_completed: "Pet profile completed",
  service_deployed_vet: "Authorized vet service",
  service_deployed_grooming: "Authorized grooming service",
  admin_manual_award: "Manual adjustment",
};

function grouped(n: number): string {
  return n.toLocaleString("en-US");
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function LedgerRows({ history }: { history: LedgerEntry[] }) {
  if (history.length === 0) {
    return (
      <p className="text-xs px-4 py-3" style={{ color: MUTED }}>
        No PawPoints activity yet.
      </p>
    );
  }

  return (
    <ul className="divide-y" style={{ borderColor: BORDER }}>
      {history.map((entry) => (
        <li
          key={entry.id}
          className="px-4 py-2 flex items-center justify-between gap-4"
          style={{ borderColor: BORDER }}
        >
          <div className="min-w-0">
            <p className="text-xs font-medium" style={{ color: NAVY }}>
              {ACTIVITY_LABELS[entry.activity_type] ?? entry.activity_type}
            </p>
            <p className="text-[0.6875rem]" style={{ color: MUTED }}>
              {formatDate(entry.created_at)}
              {entry.notes ? ` · ${entry.notes}` : ""}
            </p>
          </div>
          <span
            className="text-xs font-semibold tabular-nums shrink-0"
            style={{ color: entry.points < 0 ? MUTED : NAVY }}
          >
            {entry.points > 0 ? "+" : ""}
            {grouped(entry.points)}
          </span>
        </li>
      ))}
    </ul>
  );
}

function AwardForm({
  member,
  onDone,
}: {
  member: MemberBalance;
  onDone: () => void;
}) {
  const router = useRouter();
  const [state, formAction, pending] = useActionState(awardPointsAction, {
    error: null,
  });
  const [attempts, setAttempts] = useState(0);

  // Close only on a *successful* submit. The initial state also carries
  // error: null, so the attempt counter is what separates "not submitted yet"
  // from "submitted and it worked" — without it a failed award would close the
  // form and take its own error message with it.
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
      className="px-4 py-3 border-t space-y-3"
      style={{ borderColor: BORDER }}
    >
      <input type="hidden" name="member_id" value={member.member_id} />
      <div className="flex flex-wrap items-end gap-3">
        <label className="flex flex-col gap-1">
          <span
            className="text-[0.6875rem] font-semibold uppercase tracking-widest"
            style={{ color: MUTED }}
          >
            Points
          </span>
          <input
            name="points"
            type="number"
            step={1}
            required
            placeholder="100"
            className="w-24 rounded-lg border px-3 py-1.5 text-sm tabular-nums"
            style={{ borderColor: BORDER, color: NAVY }}
          />
        </label>
        <label className="flex flex-col gap-1 flex-1 min-w-[12rem]">
          <span
            className="text-[0.6875rem] font-semibold uppercase tracking-widest"
            style={{ color: MUTED }}
          >
            Reason
          </span>
          <input
            name="notes"
            type="text"
            required
            placeholder="Event attendance — Pet Walk, Aug 16"
            className="w-full rounded-lg border px-3 py-1.5 text-sm"
            style={{ borderColor: BORDER, color: NAVY }}
          />
        </label>
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg px-3 py-1.5 text-sm font-semibold text-white disabled:opacity-60 inline-flex items-center gap-1.5"
          style={{ backgroundColor: NAVY }}
        >
          {pending ? <Loader2 size={13} className="animate-spin" /> : <Plus size={13} />}
          Award
        </button>
        <button
          type="button"
          onClick={onDone}
          aria-label="Cancel award"
          className="rounded-lg px-2 py-1.5 text-sm"
          style={{ color: MUTED }}
        >
          <X size={14} />
        </button>
      </div>
      <p className="text-[0.6875rem]" style={{ color: MUTED }}>
        A negative number deducts. The reason is stored on the ledger entry — it is
        the only record of why a balance changed outside normal member activity.
      </p>
      {state.error && (
        <p
          className="text-xs flex items-center gap-1.5"
          style={{ color: "oklch(0.52 0.18 25)" }}
        >
          <AlertCircle size={13} />
          {state.error}
        </p>
      )}
    </form>
  );
}

function MemberRow({ member }: { member: MemberBalance }) {
  const [expanded, setExpanded] = useState(false);
  const [awarding, setAwarding] = useState(false);
  const [ledger, setLedger] = useState<MemberLedger | null>(null);
  const [loading, startLoad] = useTransition();

  function toggle() {
    const next = !expanded;
    setExpanded(next);
    if (next && !ledger) {
      startLoad(async () => {
        setLedger(await fetchMemberLedgerAction(member.member_id));
      });
    }
  }

  return (
    <li
      className="border-b last:border-b-0"
      style={{ borderColor: BORDER }}
    >
      <div className="px-4 py-3 flex items-center gap-4">
        <button
          type="button"
          onClick={toggle}
          className="flex-1 min-w-0 text-left flex items-center gap-3"
          aria-expanded={expanded}
        >
          <ChevronDown
            size={14}
            className="shrink-0 transition-transform duration-150"
            style={{
              color: MUTED,
              transform: expanded ? "rotate(0deg)" : "rotate(-90deg)",
            }}
          />
          <div className="min-w-0">
            <p className="text-sm font-medium truncate" style={{ color: NAVY }}>
              {member.first_name} {member.last_name}
            </p>
            <p className="text-xs truncate" style={{ color: MUTED }}>
              {member.email ?? "no email"}
              {member.plan_type ? ` · ${member.plan_type}` : ""}
            </p>
          </div>
        </button>

        <div className="text-right shrink-0">
          <p
            className="text-sm font-bold tabular-nums"
            style={{ color: member.current_balance > 0 ? NAVY : MUTED }}
          >
            {grouped(member.current_balance)}
          </p>
          <p className="text-[0.6875rem] tabular-nums" style={{ color: MUTED }}>
            {grouped(member.lifetime_earned)} earned
          </p>
        </div>

        <button
          type="button"
          onClick={() => {
            setAwarding((v) => !v);
            setExpanded(true);
          }}
          title={`Award or deduct points for ${member.first_name} ${member.last_name}`}
          aria-label={`Award or deduct points for ${member.first_name} ${member.last_name}`}
          className="shrink-0 rounded-lg border p-1.5 transition-colors"
          style={{ borderColor: BORDER, color: awarding ? NAVY : MUTED }}
        >
          <Coins size={14} />
        </button>
      </div>

      {expanded && (
        <div style={{ backgroundColor: "oklch(0.97 0.01 80)" }}>
          {awarding && (
            <AwardForm member={member} onDone={() => setAwarding(false)} />
          )}
          {loading ? (
            <p
              className="text-xs px-4 py-3 flex items-center gap-2"
              style={{ color: MUTED }}
            >
              <Loader2 size={13} className="animate-spin" />
              Loading ledger…
            </p>
          ) : (
            <LedgerRows history={ledger?.history ?? []} />
          )}
        </div>
      )}
    </li>
  );
}

export function PawPointsMembersTable({
  members: initialMembers,
}: {
  members: MemberBalance[];
}) {
  const [members, setMembers] = useState(initialMembers);
  const [search, setSearch] = useState("");
  const [searching, startSearch] = useTransition();

  useEffect(() => {
    setMembers(initialMembers);
  }, [initialMembers]);

  function runSearch(term: string) {
    setSearch(term);
    startSearch(async () => {
      setMembers(await fetchMemberBalancesAction(term));
    });
  }

  return (
    <section>
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3 mb-3">
        <div>
          <h2 className="text-sm font-semibold" style={{ color: NAVY }}>
            PawPoints by member
            <span className="font-normal ml-2" style={{ color: MUTED }}>
              {members.length}
            </span>
          </h2>
          <p className="text-xs mt-0.5" style={{ color: MUTED }}>
            Expand a member for their full ledger, or use the coin button to award
            or correct points.
          </p>
        </div>
        <div className="relative">
          <Search
            size={13}
            className="absolute left-3 top-1/2 -translate-y-1/2"
            style={{ color: MUTED }}
          />
          <input
            type="search"
            value={search}
            onChange={(e) => runSearch(e.target.value)}
            aria-label="Search members by name or email"
            placeholder="Name or email"
            className="rounded-lg border pl-8 pr-3 py-1.5 text-sm w-full sm:w-64"
            style={{ borderColor: BORDER, color: NAVY, backgroundColor: SURFACE }}
          />
        </div>
      </div>

      {members.length === 0 ? (
        <p
          className="text-sm rounded-xl border px-5 py-8 text-center"
          style={{ color: MUTED, borderColor: BORDER, backgroundColor: SURFACE }}
        >
          {search ? `No members match “${search}”.` : "No members yet."}
        </p>
      ) : (
        <ul
          className="rounded-xl border overflow-hidden"
          style={{
            borderColor: BORDER,
            backgroundColor: SURFACE,
            opacity: searching ? 0.6 : 1,
          }}
        >
          {members.map((member) => (
            <MemberRow key={member.member_id} member={member} />
          ))}
        </ul>
      )}
    </section>
  );
}
