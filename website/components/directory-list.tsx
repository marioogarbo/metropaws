"use client";

import { useId, useMemo, useState } from "react";
import { Clock, Globe, Mail, MapPin, Phone, Search, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { mapUrl, telHref, websiteLabel } from "@/lib/directory";
import {
  SERVICE_FILTERS,
  filterSlugs,
  matchesFilter,
  serviceLabel,
  type ServiceFilterId,
} from "@/lib/directory-taxonomy";
import type { DirectoryProvider } from "@/types/directory";

type FilterId = ServiceFilterId | "all";

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

// ── Row pieces ────────────────────────────────────────────────────────────────

function ServiceTags({
  provider,
  activeFilter,
}: {
  provider: DirectoryProvider;
  activeFilter: FilterId;
}) {
  // Highlighting the tags that caused the match answers "why is this here?"
  // without a word of explanation.
  const highlighted = activeFilter === "all" ? [] : filterSlugs(activeFilter);

  return (
    <ul className="mt-2 flex flex-wrap gap-1.5">
      {provider.services.map((slug) => {
        const isMatch = highlighted.includes(slug);
        return (
          <li key={slug}>
            <span
              className={cn(
                "inline-block rounded-full border px-2.5 py-1 text-xs font-medium",
                "transition-colors duration-150 motion-reduce:transition-none",
                isMatch
                  ? "border-(--color-navy) bg-(--color-navy) text-(--color-surface)"
                  : "border-(--color-ink-faint) text-(--color-ink-muted)",
              )}
            >
              {serviceLabel(slug)}
            </span>
          </li>
        );
      })}
    </ul>
  );
}

function DetailRow({
  icon: Icon,
  label,
  emphasis,
  children,
}: {
  icon: typeof Clock;
  label: string;
  /** Opening hours carry more decision weight than a website URL. */
  emphasis?: boolean;
  children: React.ReactNode;
}) {
  return (
    <div className="flex gap-2.5">
      <Icon
        size={14}
        className={cn(
          "mt-0.75 shrink-0",
          emphasis ? "text-(--color-ink-muted)" : "text-(--color-ink-faint)",
        )}
        aria-hidden="true"
      />
      <p
        className={cn(
          "text-sm leading-relaxed",
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

function ProviderRow({
  provider,
  activeFilter,
}: {
  provider: DirectoryProvider;
  activeFilter: FilterId;
}) {
  const tel = telHref(provider.phone);
  const map = mapUrl(provider);

  return (
    <li
      className={cn(
        "border-t border-(--color-ink-faint)/40",
        "transition-colors duration-150 motion-reduce:transition-none",
        // A partner is marked by a wash of the brand gold rather than a
        // coloured edge, so the row still reads as part of one list.
        provider.is_partner
          ? "bg-(--color-gold-wash) hover:bg-(--color-gold-wash-hover) focus-within:bg-(--color-gold-wash-hover)"
          : "hover:bg-(--color-cream-warm)/70 focus-within:bg-(--color-cream-warm)/70",
      )}
    >
      <div className="grid gap-x-10 gap-y-4 px-4 py-5 md:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)] md:py-6">
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

          <ServiceTags provider={provider} activeFilter={activeFilter} />

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
                      className="inline-flex items-center gap-1 whitespace-nowrap rounded-xs py-1.5 -my-1.5 font-semibold text-(--color-navy) underline underline-offset-4 hover:text-(--color-gold-deep) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors duration-150 motion-reduce:transition-none"
                    >
                      View on map
                      <span className="sr-only">: {provider.name}</span>
                      <span aria-hidden="true">→</span>
                    </a>
                  </>
                )}
              </DetailRow>
            </div>
          )}
        </div>

        {/* Hours and contact split into two columns once there is room, so the
            row reaches the full width instead of trailing off into dead space,
            and hours can be scanned straight down the page. */}
        <div className="grid gap-x-8 gap-y-2.5 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] xl:items-start">
          {provider.hours && (
            <DetailRow icon={Clock} label="Hours" emphasis>
              {provider.hours}
            </DetailRow>
          )}

          <div className="space-y-2.5">
            {provider.phone && (
              <DetailRow icon={Phone} label="Contact">
                {tel ? (
                  <a href={tel} className={DETAIL_LINK_CLASS}>
                    {provider.phone}
                  </a>
                ) : (
                  // Some listings carry "Please verify directly with the clinic"
                  // where a number belongs. True, and never a tappable link.
                  provider.phone
                )}
              </DetailRow>
            )}

            {provider.email && (
              <DetailRow icon={Mail} label="Email">
                <a
                  href={`mailto:${provider.email}`}
                  className={cn(DETAIL_LINK_CLASS, "break-all")}
                >
                  {provider.email}
                </a>
              </DetailRow>
            )}

            {provider.website && (
              <DetailRow icon={Globe} label="Website">
                <a
                  href={provider.website}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={cn(DETAIL_LINK_CLASS, "break-all")}
                >
                  {websiteLabel(provider.website)}
                </a>
              </DetailRow>
            )}
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
  const [activeFilter, setActiveFilter] = useState<FilterId>("all");
  const searchId = useId();

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
      <section className="bg-(--color-navy) border-t border-white/10 pt-7 pb-11 md:pt-9 md:pb-14">
        <div className="max-w-6xl mx-auto px-6">
          <h2 className="sr-only">Search the directory</h2>
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between lg:gap-10">
            <div className="relative sm:max-w-md lg:w-80 lg:max-w-none lg:shrink-0">
              <label htmlFor={searchId} className="sr-only">
                Search by name, service, or area
              </label>
              <Search
                size={15}
                className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-(--color-silver)"
                aria-hidden="true"
              />
              <input
                id={searchId}
                type="search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Search a name, service, or area"
                className={cn(
                  // white/40, not /25: a form control's own boundary needs
                  // 3:1 against its surroundings (WCAG 1.4.11). On navy, /25
                  // is 2.06:1 and /40 is 3.70:1.
                  "w-full min-h-11 rounded-lg border border-white/40 bg-white/5",
                  "pl-10 pr-10 text-sm text-(--color-surface) placeholder:text-(--color-silver)",
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
                  onClick={() => setQuery("")}
                  aria-label="Clear search"
                  className="absolute right-1.5 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-md text-(--color-silver) hover:bg-white/10 hover:text-(--color-surface) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors duration-150 motion-reduce:transition-none"
                >
                  <X size={15} aria-hidden="true" />
                </button>
              )}
            </div>

            <div
              className="-mx-6 overflow-x-auto px-6 pb-1 lg:mx-0 lg:overflow-visible lg:px-0 lg:pb-0"
              role="group"
              aria-label="Filter by service"
            >
              <div className="flex gap-2 lg:flex-wrap lg:justify-end">
                {[{ id: "all" as const, label: "All" }, ...SERVICE_FILTERS].map(
                  ({ id, label }) => {
                    const isActive = activeFilter === id;
                    return (
                      <button
                        key={id}
                        type="button"
                        onClick={() => setActiveFilter(id)}
                        aria-pressed={isActive}
                        className={cn(
                          "inline-flex min-h-11 shrink-0 items-center gap-2 rounded-lg border px-4 text-sm font-medium",
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
          <h2 className="sr-only">Pet care providers</h2>

          <div className="flex flex-wrap items-baseline justify-between gap-x-6 gap-y-2">
            <p
              className="text-sm text-(--color-ink-muted)"
              role="status"
              aria-live="polite"
            >
              {visible.length === providers.length
                ? `${providers.length} providers listed`
                : `${visible.length} of ${providers.length} providers`}
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
            <ul className="mt-4 border-b border-(--color-ink-faint)/40">
              {visible.map((provider) => (
                <ProviderRow
                  key={provider.id}
                  provider={provider}
                  activeFilter={activeFilter}
                />
              ))}
            </ul>
          ) : (
            <div className="mt-4 border-y border-(--color-ink-faint)/40 px-4 py-16 text-center">
              <p className="text-sm font-semibold text-(--color-navy)">
                Nothing matches that yet
              </p>
              <p className="mx-auto mt-2 max-w-[46ch] text-sm text-(--color-ink-muted) leading-relaxed">
                The directory covers Las Piñas and the areas next to it, so a
                provider further out may simply not be listed. Try a shorter
                search, or clear the filters to see everything.
              </p>
              <button
                type="button"
                onClick={clearFilters}
                className="mt-6 inline-flex min-h-11 items-center rounded-lg border border-(--color-navy) px-5 text-sm font-semibold text-(--color-navy) hover:bg-(--color-navy) hover:text-(--color-surface) active:bg-(--color-navy-mid) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors duration-150 motion-reduce:transition-none"
              >
                Show all providers
              </button>
            </div>
          )}
        </div>
      </section>
    </>
  );
}
