import { Info } from "lucide-react";

/**
 * The disclaimer sits beside the headline rather than under the list.
 *
 * It is the only part of this page with consequences: a member who has a bad
 * visit needs to have already read that MetroPaws did not vouch for the
 * business. Putting it in the hero means it is read in the same breath as the
 * promise, not discovered afterwards in small print.
 */
/*
 * Body copy on navy uses `--color-silver` (5.77:1), not `--color-ink-faint`
 * (3.23:1). The faint token is the site's habit for text on navy but it misses
 * WCAG AA for body size, and the disclaimer below is the last text on this page
 * that should be hard to read.
 */
export function DirectoryHero() {
  return (
    // Bottom padding is short because DirectoryList's search band continues
    // this same navy field directly below it. The two read as one dark zone:
    // what the list is, then the controls for it, then the results on cream.
    //
    // The max-height rule catches a phone held sideways: 844x390 is wide enough
    // for the md: padding but only 390px tall, so the intro would eat two
    // screens before a single listing.
    <section className="bg-(--color-navy) pt-12 pb-11 md:pt-20 md:pb-14 [@media(max-height:540px)]:pt-8 [@media(max-height:540px)]:pb-8">
      <div className="max-w-6xl mx-auto px-6">
        {/* A phone held sideways has the width for two columns but almost no
            height, so it gets the desktop split early rather than stacking the
            disclaimer under the headline and pushing every listing off-screen. */}
        <div className="grid gap-8 lg:grid-cols-[1.15fr_1fr] lg:gap-16 lg:items-start [@media(max-height:540px)_and_(min-width:640px)]:grid-cols-[1.15fr_1fr] [@media(max-height:540px)_and_(min-width:640px)]:gap-10 [@media(max-height:540px)_and_(min-width:640px)]:items-start">
          <div className="mp-reveal">
            <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
              Around Las Piñas
            </p>
            <h1 className="mt-3 text-3xl md:text-5xl [@media(max-height:540px)]:text-3xl font-bold text-(--color-surface) tracking-tight leading-tight text-balance">
              Find pet care near you
            </h1>
            {/* "Gathered in one list" described the page to someone looking at
                it. What a first-time visitor actually wants to know is whether
                this is a members-only benefit, so the second sentence answers
                that instead. */}
            <p className="mt-4 text-sm text-(--color-silver) leading-relaxed max-w-[52ch]">
              Vets, groomers, pet stores, and boarding around Las Piñas. Free to
              use, whether or not you are a MetroPaws member.
            </p>
          </div>

          {/* Capped below lg, where the hero is a single column and an
              uncapped panel would run the disclaimer past 80ch. */}
          <div className="max-w-2xl rounded-xl border border-white/15 p-5 md:p-7 lg:max-w-none">
            <div className="flex items-center gap-2.5">
              <Info
                size={16}
                className="text-(--color-gold) shrink-0"
                aria-hidden="true"
              />
              {/* The old heading, "What this list is, and what it is not", was
                  shape without content: a reader who skims headings learned
                  nothing and had to read the paragraph to find the one fact
                  that matters. This heading is that fact. */}
              <h2 className="text-sm font-semibold text-(--color-gold)">
                A listing here is not a recommendation
              </h2>
            </div>
            <p className="mt-3 text-sm text-(--color-silver) leading-relaxed">
              Being listed is not accreditation, endorsement, or any agreement
              with MetroPaws, unless marked{" "}
              <strong className="font-semibold text-(--color-surface)">
                MetroPaws Partner
              </strong>
              . Details change, so confirm hours and fees before you go.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
