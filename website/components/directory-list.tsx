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
  const highlighted =
    activeFilter === "all" ? [] : filterSlugs(activeFilter);

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
  children,
}: {
  icon: typeof Clock;
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex gap-2.5">
      <Icon
        size={14}
        className="mt-0.5 shrink-0 text-(--color-ink-faint)"
        aria-hidden="true"
      />
      <p className="text-sm text-(--color-ink-muted) leading-relaxed">
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
    <li className="border-t border-(--color-ink-faint)/45 transition-colors duration-150 motion-reduce:transition-none hover:bg-(--color-cream-warm)/60 focus-within:bg-(--color-cream-warm)/60">
      <div className="grid gap-x-10 gap-y-3 px-4 py-5 md:grid-cols-[minmax(0,1.25fr)_minmax(0,1fr)] md:py-6">
        <div>
          <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
            <h3 className="text-base font-semibold text-(--color-navy) leading-snug text-balance">
              {provider.name}
            </h3>
            {provider.is_partner && (
              // Darkened gold, not `--color-gold`: at 12px the brand gold gives
              // navy text only 3.52:1, under the 4.5:1 AA floor for this size.
              // This keeps the badge in the gold family at 12.5:1.
              <span className="rounded-full bg-[oklch(0.52_0.08_82)] px-2.5 py-1 text-xs font-semibold uppercase tracking-wide text-(--color-cream)">
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
                      className="inline-flex items-center gap-1 whitespace-nowrap rounded py-1.5 -my-1.5 font-semibold text-(--color-navy) underline underline-offset-4 hover:text-(--color-ink) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors"
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

        <div className="space-y-2.5 md:pt-0.5">
          {provider.hours && (
            <DetailRow icon={Clock} label="Hours">
              {provider.hours}
            </DetailRow>
          )}

          {provider.phone && (
            <DetailRow icon={Phone} label="Contact">
              {tel ? (
                <a
                  href={tel}
                  className="underline underline-offset-2 decoration-(--color-ink-faint) hover:text-(--color-navy) hover:decoration-(--color-navy) transition-colors"
                >
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
                className="underline underline-offset-2 decoration-(--color-ink-faint) hover:text-(--color-navy) hover:decoration-(--color-navy) transition-colors break-all"
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
                className="underline underline-offset-2 decoration-(--color-ink-faint) hover:text-(--color-navy) hover:decoration-(--color-navy) transition-colors break-all"
              >
                {websiteLabel(provider.website)}
              </a>
            </DetailRow>
          )}

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
    <section className="bg-(--color-cream) py-12 md:py-16">
      <div className="max-w-6xl mx-auto px-6">
        <h2 className="sr-only">Pet care providers</h2>

        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="relative lg:max-w-sm lg:flex-1">
            <label htmlFor={searchId} className="sr-only">
              Search by name, service, or area
            </label>
            <Search
              size={15}
              className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-(--color-ink-muted)"
              aria-hidden="true"
            />
            <input
              id={searchId}
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search a name, service, or area"
              className={cn(
                "w-full min-h-11 rounded-lg border border-(--color-ink-faint) bg-(--color-surface)",
                "pl-10 pr-10 text-sm text-(--color-ink) placeholder:text-(--color-ink-muted)",
                "focus:outline-none focus:ring-2 focus:ring-(--color-gold) focus:border-transparent",
                "transition-shadow duration-150 motion-reduce:transition-none",
              )}
            />
            {query && (
              <button
                type="button"
                onClick={() => setQuery("")}
                aria-label="Clear search"
                className="absolute right-1.5 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-md text-(--color-ink-muted) hover:text-(--color-navy) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors"
              >
                <X size={15} aria-hidden="true" />
              </button>
            )}
          </div>

          <div
            className="-mx-6 overflow-x-auto px-6 lg:mx-0 lg:overflow-visible lg:px-0"
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
                        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold)",
                        "transition-colors duration-150 motion-reduce:transition-none",
                        isActive
                          ? "border-(--color-navy) bg-(--color-navy) text-(--color-surface)"
                          : "border-(--color-ink-faint) bg-(--color-surface) text-(--color-ink-muted) hover:border-(--color-navy) hover:text-(--color-navy)",
                      )}
                    >
                      {label}
                      <span
                        className={cn(
                          "text-xs tabular-nums",
                          isActive
                            ? "text-(--color-gold)"
                            : "text-(--color-ink-faint)",
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

        <p
          className="mt-6 text-sm text-(--color-ink-muted)"
          role="status"
          aria-live="polite"
        >
          {visible.length === providers.length
            ? `${providers.length} providers listed`
            : `${visible.length} of ${providers.length} providers`}
        </p>

        {visible.length > 0 ? (
          <ul className="mt-2 border-b border-(--color-ink-faint)/45">
            {visible.map((provider) => (
              <ProviderRow
                key={provider.id}
                provider={provider}
                activeFilter={activeFilter}
              />
            ))}
          </ul>
        ) : (
          <div className="mt-2 border-y border-(--color-ink-faint)/45 px-4 py-16 text-center">
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
              className="mt-6 inline-flex min-h-11 items-center rounded-lg border border-(--color-navy) px-5 text-sm font-semibold text-(--color-navy) hover:bg-(--color-navy) hover:text-(--color-surface) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) transition-colors duration-150 motion-reduce:transition-none"
            >
              Show all providers
            </button>
          </div>
        )}

        {isFiltered && visible.length > 0 && (
          <button
            type="button"
            onClick={clearFilters}
            className="mt-6 text-sm font-medium text-(--color-ink-muted) underline underline-offset-4 hover:text-(--color-navy) focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold) rounded transition-colors"
          >
            Clear filters
          </button>
        )}
      </div>
    </section>
  );
}
