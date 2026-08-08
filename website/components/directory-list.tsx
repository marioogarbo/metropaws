"use client";

import { Fragment, useId, useMemo, useRef, useState } from "react";
import {
  Clock,
  Globe,
  Info,
  Mail,
  MapPin,
  Phone,
  Search,
  SearchX,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { isUnverified, mapUrl, telHref, websiteLabel } from "@/lib/directory";
import {
  SERVICE_FILTERS,
  filterSlugs,
  matchesFilter,
  serviceLabel,
  type DirectoryFilterId,
} from "@/lib/directory-taxonomy";
import { ServiceMark, filterIcon } from "@/components/directory-service-mark";
import type { DirectoryProvider } from "@/types/directory";

/**
 * Fold accents so "las pinas" finds "Las Piñas".
 *
 * Most people type the plain n. Without this the search box looks broken to
 * exactly the people the directory is for.
 */
function normalize(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase();
}

function searchIndex(provider: DirectoryProvider): string {
  return normalize(
    [
      provider.name,
      provider.address ?? "",
      provider.services.map(serviceLabel).join(" "),
    ].join(" "),
  );
}

const DETAIL_LINK_CLASS =
  "underline underline-offset-2 decoration-(--color-ink-faint) hover:text-(--color-navy) hover:decoration-(--color-navy) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) rounded-xs transition-colors duration-150 motion-reduce:transition-none";

/**
 * Contact links get a real 44px tap band below `md`, then collapse back to
 * inline text where a pointer is likely.
 *
 * Measured at 320/360/390px, every phone, email, and website link was an 18px
 * target. On a page someone opens because their dog needs a vet, the phone
 * number is the action, and 18px is not a thing you hit one-handed. Padding
 * alone would not do: at a 28px pitch the expanded hit boxes overlap and steal
 * each other's taps, so the row itself has to carry the height.
 */
const CONTACT_LINK_CLASS = cn(
  DETAIL_LINK_CLASS,
  "flex min-h-11 items-center pointer-fine:inline pointer-fine:min-h-0",
);

// ── Row pieces ────────────────────────────────────────────────────────────────

/**
 * The listing's services, as one line of text.
 *
 * These were bordered pills. Eleven of nineteen listings carry a single
 * service, so the pill was a lone bordered capsule restating the mark beside
 * it, and the four-service listings turned into a hedge of borders. The mark
 * now answers "what kind of place is this?" at a glance, which leaves this as
 * the detail layer, and a detail layer does not need chrome.
 *
 * Emphasising the labels that caused the match still answers "why is this in my
 * filtered results?" without a word of explanation.
 */
function ServiceLine({
  provider,
  activeFilter,
}: {
  provider: DirectoryProvider;
  activeFilter: DirectoryFilterId;
}) {
  const matched = activeFilter === "all" ? [] : filterSlugs(activeFilter);

  return (
    <p className="mt-1.5 text-sm text-(--color-ink-muted)">
      {provider.services.map((slug, index) => (
        <Fragment key={slug}>
          {index > 0 && (
            <span className="text-(--color-ink-faint)" aria-hidden="true">
              {" / "}
            </span>
          )}
          <span
            className={cn(
              "transition-colors duration-150 motion-reduce:transition-none",
              matched.includes(slug) && "font-semibold text-(--color-navy)",
            )}
          >
            {serviceLabel(slug)}
          </span>
        </Fragment>
      ))}
    </p>
  );
}

/**
 * What we could not confirm, said once.
 *
 * Replaces the pair of near-identical apologies the placeholder rows used to
 * print ("Please verify before visiting" in hours, "Please verify directly with
 * the establishment" in contact). Neither told the reader anything actionable;
 * this names the gap and points at the map listing, which is where a current
 * number or opening time actually lives.
 */
function unconfirmedNote(hasHours: boolean, hasPhone: boolean): string | null {
  if (hasHours && hasPhone) return null;
  if (!hasHours && !hasPhone) {
    return "Hours and phone not confirmed. The map listing usually has both.";
  }
  if (!hasHours) return "Hours not confirmed. The map listing usually shows them.";
  return "Phone not confirmed. The map listing usually shows it.";
}

function DetailRow({
  icon: Icon,
  label,
  emphasis,
  action,
  children,
}: {
  icon: typeof Clock;
  label: string;
  /** Opening hours carry more decision weight than a website URL. */
  emphasis?: boolean;
  /** Holds a tappable link, so the icon centres on the 44px band on touch. */
  action?: boolean;
  children: React.ReactNode;
}) {
  return (
    <div className={cn("flex gap-2.5", action && "items-center pointer-fine:items-start")}>
      <Icon
        size={14}
        className={cn(
          "shrink-0",
          action ? "pointer-fine:mt-0.75" : "mt-0.75",
          emphasis ? "text-(--color-ink-muted)" : "text-(--color-ink-faint)",
        )}
        aria-hidden="true"
      />
      <p
        className={cn(
          "text-sm leading-relaxed",
          action && "min-w-0 flex-1",
          emphasis
            ? "font-medium text-(--color-ink)"
            : "text-(--color-ink-muted)",
        )}
      >
        <span className="sr-only">{label}: </span>
        {children}
      </p>
    </div>
  );
}

/** Rows past this point settle together, so row 19 is never left waiting. */
const MAX_STAGGER_STEPS = 8;
const STAGGER_STEP_MS = 20;

function ProviderRow({
  provider,
  activeFilter,
  index,
}: {
  provider: DirectoryProvider;
  activeFilter: DirectoryFilterId;
  index: number;
}) {
  const tel = telHref(provider.phone);
  const map = mapUrl(provider);
  // A "Please verify..." string in either field is an absence, not a value.
  const hours = isUnverified(provider.hours) ? null : provider.hours;
  const note = unconfirmedNote(Boolean(hours), Boolean(tel));

  return (
    <li
      className={cn(
        "mp-settle group border-t border-(--color-ink-faint)/40",
        "transition-colors duration-150 motion-reduce:transition-none",
        // A partner is marked by a wash of the brand gold rather than a
        // coloured edge, so the row still reads as part of one list.
        provider.is_partner
          ? "bg-(--color-gold-wash) hover:bg-(--color-gold-wash-hover) focus-within:bg-(--color-gold-wash-hover)"
          : "hover:bg-(--color-cream-warm)/70 focus-within:bg-(--color-cream-warm)/70",
      )}
      style={{
        animationDelay: `${Math.min(index, MAX_STAGGER_STEPS) * STAGGER_STEP_MS}ms`,
      }}
    >
      {/* The mark leads the row from OUTSIDE the two-column grid, not from
          inside the name block. Inside, it indented the name, tags, and address
          while hours and contacts stayed flush left, and on a phone (where the
          two columns stack) that left a visibly ragged edge mid-row. Out here
          every line of content shares one left edge at every breakpoint, and
          the marks form an unbroken rail to scan down instead of nineteen
          identically shaped blocks of text. */}
      <div className="flex gap-3 px-4 py-5 md:gap-4 md:py-6">
        <ServiceMark services={provider.services} />

        {/* min-w-0 so a long address wraps instead of widening the column. */}
        {/* 1.1fr, down from the 1.2fr this grid used before the mark existed.
            The mark takes 56px off the row, which came out of the hours column
            and pushed four listings' opening hours onto a third line. Names and
            addresses wrap gracefully; a set of hours does not. */}
        <div className="grid min-w-0 flex-1 gap-x-8 gap-y-4 md:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)]">
          <div>
            <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
              <h3 className="text-base font-semibold text-(--color-navy) leading-snug text-balance">
                {provider.name}
              </h3>
              {provider.is_partner && (
                <span className="rounded-full bg-(--color-gold-deep) px-2.5 py-1 text-xs font-semibold uppercase tracking-wide text-(--color-cream)">
                  MetroPaws Partner
                </span>
              )}
            </div>

            <ServiceLine provider={provider} activeFilter={activeFilter} />

            {provider.address && (
              <div className="mt-3">
                {/* The map link rides with the address because that is what it
                    acts on. As its own button it added a row of height to every
                    listing for no extra meaning. */}
                <DetailRow icon={MapPin} label="Address">
                  {provider.address}
                  {map && (
                    <>
                      {" "}
                      <a
                        href={map}
                        target="_blank"
                        rel="noopener noreferrer"
                        // Vertical padding on an inline element expands the tap
                        // box without changing the line box, so this reaches
                        // 44px on touch while still flowing inside the address.
                        //
                        // Named `group/map`, not a bare `group`: the row is a
                        // group now (it tints the service mark on hover), and a
                        // nested bare group would leave `group-hover:` below
                        // matching the row, leaning the arrow on any row hover.
                        className="group/map inline-flex items-center gap-1 whitespace-nowrap rounded-xs py-3.5 -my-3.5 pointer-fine:py-1.5 pointer-fine:-my-1.5 font-semibold text-(--color-navy) underline underline-offset-4 hover:text-(--color-gold-deep) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors duration-150 motion-reduce:transition-none"
                      >
                        View on map
                        <span className="sr-only">: {provider.name}</span>
                        {/* The arrow leans toward where it is taking you. */}
                        <span
                          aria-hidden="true"
                          className="transition-transform duration-150 ease-out group-hover/map:translate-x-0.5 group-focus-visible/map:translate-x-0.5 motion-reduce:transition-none motion-reduce:group-hover/map:translate-x-0"
                        >
                          →
                        </span>
                      </a>
                    </>
                  )}
                </DetailRow>
              </div>
            )}
          </div>

          {/* Hours and contact split into two columns once there is room, so
              the row reaches the full width instead of trailing off into dead
              space, and hours can be scanned straight down the page. */}
          <div className="grid gap-x-8 gap-y-2.5 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:items-start">
            {hours ? (
              <DetailRow icon={Clock} label="Hours" emphasis>
                {hours}
              </DetailRow>
            ) : (
              note && (
                <DetailRow icon={Info} label="Note">
                  {note}
                </DetailRow>
              )
            )}

            <div className="space-y-0.5 pointer-fine:space-y-2.5">
              {tel && (
                <DetailRow icon={Phone} label="Contact" action>
                  <a href={tel} className={CONTACT_LINK_CLASS}>
                    {provider.phone}
                  </a>
                </DetailRow>
              )}

              {/* Hours are real but the number is not: the note has nowhere
                  else to go, so it rides in the contact column instead. */}
              {hours && note && (
                <DetailRow icon={Info} label="Note">
                  {note}
                </DetailRow>
              )}

              {provider.email && (
                <DetailRow icon={Mail} label="Email" action>
                  <a
                    href={`mailto:${provider.email}`}
                    className={cn(CONTACT_LINK_CLASS, "break-all")}
                  >
                    {provider.email}
                  </a>
                </DetailRow>
              )}

              {provider.website && (
                <DetailRow icon={Globe} label="Website" action>
                  <a
                    href={provider.website}
                    target="_blank"
                    rel="noopener noreferrer"
                    className={cn(CONTACT_LINK_CLASS, "break-all")}
                  >
                    {websiteLabel(provider.website)}
                  </a>
                </DetailRow>
              )}
            </div>
          </div>
        </div>
      </div>
    </li>
  );
}

// ── The list ──────────────────────────────────────────────────────────────────

export function DirectoryList({
  providers,
}: {
  providers: DirectoryProvider[];
}) {
  const [query, setQuery] = useState("");
  const [activeFilter, setActiveFilter] = useState<DirectoryFilterId>("all");
  const searchId = useId();
  const searchRef = useRef<HTMLInputElement>(null);

  /**
   * Clearing puts the caret back in the field.
   *
   * Without this the focused element is a button that just unmounted, so focus
   * falls to the top of the document and the next keystroke goes nowhere. The
   * expected move after clearing a search is to type again.
   */
  function clearQuery() {
    setQuery("");
    searchRef.current?.focus();
  }

  const indexed = useMemo(
    () => providers.map((p) => ({ provider: p, haystack: searchIndex(p) })),
    [providers],
  );

  // Counts set expectations before a chip is clicked: "Boarding 2" tells you
  // not to expect a page of results.
  const counts = useMemo(() => {
    const byFilter: Record<string, number> = { all: providers.length };
    for (const filter of SERVICE_FILTERS) {
      byFilter[filter.id] = providers.filter((p) =>
        matchesFilter(p.services, filter.id),
      ).length;
    }
    return byFilter;
  }, [providers]);

  const visible = useMemo(() => {
    const needle = normalize(query.trim());
    return indexed
      .filter(({ provider }) =>
        activeFilter === "all"
          ? true
          : matchesFilter(provider.services, activeFilter),
      )
      .filter(({ haystack }) => (needle ? haystack.includes(needle) : true))
      .map(({ provider }) => provider);
  }, [indexed, query, activeFilter]);

  const isFiltered = activeFilter !== "all" || query.trim() !== "";

  function clearFilters() {
    setQuery("");
    setActiveFilter("all");
  }

  return (
    <>
      {/*
        The controls sit on the same navy field as the hero, separated by a
        hairline. It fills what was dead space under the headline, puts the
        search within reach on a phone instead of a screen further down, and
        keeps the brand's navy share on a page that is otherwise a long light
        list.
      */}
      <section className="bg-(--color-navy) border-t border-white/10 pt-7 pb-11 md:pt-9 md:pb-14 [@media(max-height:540px)]:pt-6 [@media(max-height:540px)]:pb-6">
        <div className="max-w-6xl mx-auto px-6">
          <h2 className="sr-only">Search the directory</h2>
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between lg:gap-10">
            <div className="relative sm:max-w-md lg:w-80 lg:max-w-none lg:shrink-0">
              <label htmlFor={searchId} className="sr-only">
                Search by name, service, or area
              </label>
              {/* Label and placeholder say the same thing. They used to differ
                  ("Search a name..."), which is both ungrammatical and a
                  mismatch for anyone comparing what they hear to what they
                  see. */}
              <Search
                size={15}
                className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-(--color-silver)"
                aria-hidden="true"
              />
              <input
                id={searchId}
                ref={searchRef}
                type="search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                onKeyDown={(event) => {
                  // Escape clears the field, the way every search box does.
                  if (event.key === "Escape" && query) {
                    event.preventDefault();
                    setQuery("");
                  }
                }}
                placeholder="Search by name, service, or area"
                className={cn(
                  // white/40, not /25: a form control's own boundary needs
                  // 3:1 against its surroundings (WCAG 1.4.11). On navy, /25
                  // is 2.06:1 and /40 is 3.70:1.
                  "w-full min-h-11 rounded-lg border border-white/40 bg-white/5",
                  // 16px on phones: iOS Safari zooms the whole page when it
                  // focuses an input under 16px, which throws the layout off
                  // mid-search. Back to the brand's 14px once there is room.
                  "pl-10 pr-10 text-base pointer-fine:text-sm",
                  "text-(--color-surface) placeholder:text-(--color-silver)",
                  "hover:border-white/60",
                  "focus:outline-none focus:ring-2 focus:ring-(--color-gold) focus:border-transparent",
                  "transition-colors duration-150 motion-reduce:transition-none",
                  // Safari and Chrome draw their own clear button on
                  // type="search"; ours is keyboard reachable and labelled.
                  "[&::-webkit-search-cancel-button]:appearance-none",
                )}
              />
              {query && (
                <button
                  type="button"
                  onClick={clearQuery}
                  aria-label="Clear search"
                  className="absolute right-1.5 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-md text-(--color-silver) hover:bg-white/10 hover:text-(--color-surface) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors duration-150 motion-reduce:transition-none"
                >
                  <X size={15} aria-hidden="true" />
                </button>
              )}
            </div>

            <div
              // overscroll-x-contain stops a swipe that runs off the end of the
              // chips from becoming a browser back-navigation on iOS.
              className="-mx-6 overflow-x-auto overscroll-x-contain px-6 pb-1 lg:mx-0 lg:overflow-visible lg:px-0 lg:pb-0"
              role="group"
              aria-label="Filter by service"
            >
              <div className="flex gap-2 lg:flex-wrap lg:justify-end">
                {[{ id: "all" as const, label: "All" }, ...SERVICE_FILTERS].map(
                  ({ id, label }) => {
                    const isActive = activeFilter === id;
                    // The chip is where the glyph gets its caption. By the time
                    // a reader meets the scissors on a row, they have already
                    // seen it beside the word "Grooming", so the marks read as
                    // a vocabulary rather than as decoration to be decoded.
                    //
                    // "All" gets none, which also lets the reset chip read as a
                    // different kind of control than the four filters.
                    const Icon = filterIcon(id);
                    return (
                      <button
                        key={id}
                        type="button"
                        onClick={() => setActiveFilter(id)}
                        aria-pressed={isActive}
                        className={cn(
                          "inline-flex min-h-11 shrink-0 items-center gap-2 rounded-lg border px-4 text-sm font-medium",
                          Icon && "pl-3",
                          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) focus-visible:ring-offset-2 focus-visible:ring-offset-(--color-navy)",
                          "transition-colors duration-150 motion-reduce:transition-none",
                          isActive
                            ? // Cream fill, not gold: gold behind navy text is
                              // 3.52:1 and fails AA at this size.
                              "border-(--color-surface) bg-(--color-surface) text-(--color-navy)"
                            : // See the input above on why /40 and not /25.
                              "border-white/40 text-(--color-silver) hover:border-white/70 hover:text-(--color-surface) active:bg-white/10",
                        )}
                      >
                        {Icon && (
                          <Icon
                            size={15}
                            strokeWidth={1.75}
                            className="shrink-0"
                            aria-hidden="true"
                          />
                        )}
                        {label}
                        <span
                          className={cn(
                            "text-xs tabular-nums",
                            isActive
                              ? "text-(--color-ink-muted)"
                              : "text-(--color-silver)",
                          )}
                        >
                          {counts[id]}
                        </span>
                      </button>
                    );
                  },
                )}
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="bg-(--color-cream) pt-8 pb-16 md:pt-10 md:pb-20">
        <div className="max-w-6xl mx-auto px-6">
          {/* "Places", not "providers", throughout this page. "Provider" is HMO
              language in the Philippines, where it means an *accredited* one,
              which is the exact claim the hero disclaimer exists to deny. It is
              also already taken in the admin, where /admin/providers means
              payout targets. */}
          <h2 className="sr-only">Pet care places</h2>

          <div className="flex flex-wrap items-baseline justify-between gap-x-6 gap-y-2">
            <p
              className="text-sm text-(--color-ink-muted)"
              role="status"
              aria-live="polite"
            >
              {visible.length === providers.length
                ? `${providers.length} places`
                : `${visible.length} of ${providers.length} places`}
            </p>

            {isFiltered && visible.length > 0 && (
              <button
                type="button"
                onClick={clearFilters}
                className="text-sm font-medium text-(--color-ink-muted) underline underline-offset-4 hover:text-(--color-navy) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) rounded-xs transition-colors duration-150 motion-reduce:transition-none"
              >
                Clear filters
              </button>
            )}
          </div>

          {visible.length > 0 ? (
            /*
              Keyed on the chip only. Remounting replays the settle animation,
              which is the right acknowledgement for a discrete tap; keying on
              the query too would replay it on every keystroke and strobe.
            */
            <ul
              key={activeFilter}
              className="mt-4 border-b border-(--color-ink-faint)/40"
            >
              {visible.map((provider, index) => (
                <ProviderRow
                  key={provider.id}
                  provider={provider}
                  activeFilter={activeFilter}
                  index={index}
                />
              ))}
            </ul>
          ) : (
            <div className="mp-settle mt-4 border-y border-(--color-ink-faint)/40 px-4 py-16 text-center">
              <SearchX
                size={22}
                className="mx-auto text-(--color-ink-faint)"
                aria-hidden="true"
              />
              {/* Echoing the query confirms what was actually searched, which
                  is usually where the surprise is (a stray character, an old
                  term still in the box). */}
              <p className="mt-4 text-base font-semibold text-(--color-navy)">
                {query.trim() ? (
                  <>
                    Nothing here matches{" "}
                    <span className="text-(--color-gold-deep)">
                      &ldquo;{query.trim()}&rdquo;
                    </span>
                  </>
                ) : (
                  "Nothing in this category yet"
                )}
              </p>
              <p className="mx-auto mt-2 max-w-[46ch] text-sm text-(--color-ink-muted) leading-relaxed">
                This list covers Las Piñas and the areas next to it, so
                somewhere further out may not be here yet. Try a shorter search.
              </p>
              <button
                type="button"
                onClick={clearFilters}
                className="mt-6 inline-flex min-h-11 items-center rounded-lg border border-(--color-navy) px-5 text-sm font-semibold text-(--color-navy) hover:bg-(--color-navy) hover:text-(--color-surface) active:bg-(--color-navy-mid) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors duration-150 motion-reduce:transition-none"
              >
                Show all {providers.length} places
              </button>
            </div>
          )}
        </div>
      </section>
    </>
  );
}
