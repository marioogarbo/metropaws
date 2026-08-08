import { ChevronDown, Info } from "lucide-react";

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
    // Phone padding is tighter than the md: values on both axes. On a 375px
    // phone the first listing sat 872px down a 667px viewport, so a page people
    // open when a pet needs care asked for 1.3 screens of preamble first.
    // Desktop keeps its full breathing room, where nothing competes for the fold.
    //
    // The max-height rule catches a phone held sideways: 844x390 is wide enough
    // for the md: padding but only 390px tall. It now only needs to undo the
    // md: values, since the portrait base is already this tight.
    <section className="bg-(--color-navy) pt-8 pb-7 md:pt-20 md:pb-14 [@media(max-height:540px)]:md:pt-8 [@media(max-height:540px)]:md:pb-8">
      <div className="max-w-6xl mx-auto px-6">
        {/* A phone held sideways has the width for two columns but almost no
            height, so it gets the desktop split early rather than stacking the
            disclaimer under the headline and pushing every listing off-screen. */}
        <div className="grid gap-5 lg:grid-cols-[1.15fr_1fr] lg:gap-16 lg:items-start [@media(max-height:540px)_and_(min-width:640px)]:grid-cols-[1.15fr_1fr] [@media(max-height:540px)_and_(min-width:640px)]:gap-10 [@media(max-height:540px)_and_(min-width:640px)]:items-start">
          <div className="mp-reveal">
            {/* The eyebrow used to read "Around Las Piñas", which the paragraph
                two lines below repeats verbatim. Naming what the list *is*
                instead keeps DESIGN.md's eyebrow pattern, drops the repetition,
                and sets the non-endorsement frame before the disclaimer has to
                argue for it. */}
            <p className="text-sm font-semibold uppercase tracking-widest text-(--color-gold)">
              Community directory
            </p>
            <h1 className="mt-3 text-3xl md:text-5xl [@media(max-height:540px)]:text-3xl font-bold text-(--color-surface) tracking-tight leading-tight text-balance">
              Find pet care near you
            </h1>
            {/* "Gathered in one list" described the page to someone looking at
                it. What a first-time visitor actually wants to know is whether
                this is a members-only benefit, so the second sentence answers
                that instead. */}
            {/* "member or not" went: "everyone" already carries it, and the
                sentence was running to a third line on a 375px phone purely to
                say it twice. */}
            <p className="mt-4 text-sm text-(--color-silver) leading-relaxed max-w-[52ch]">
              Vets, groomers, pet stores, and boarding around Las Piñas. Free
              for everyone.
            </p>
          </div>

          {/* A bordered panel only below lg cost 40px of padding plus a border,
              to fence off the one thing already alone in its column. On a phone
              it becomes a hairline rule and flowing text: same prominence, same
              words, in the reading order rather than in a box.
              Capped below lg, where the hero is a single column and an uncapped
              panel would run the disclaimer past 80ch. */}
          {/* A disclosure, not a panel.
              The full statement ran 144px on a phone, the second-largest block
              on the page, which pushed the first listing to 724px on a 667px
              screen. Someone who opened this because a pet needs care met a
              whole screen of preamble.
              What stays visible is the operative sentence: this is not a
              recommendation, and confirm before you go. What folds away is the
              precise wording, which elaborates rather than warns.
              Native <details>, so it needs no JavaScript, survives a failed
              hydration, is keyboard-operable for free, and keeps the full text
              in the DOM for screen readers and for the record.
              A bordered panel only from lg, where there is room for one. */}
          <details className="group max-w-2xl border-t border-white/15 pt-5 lg:max-w-none lg:rounded-xl lg:border lg:border-white/15 lg:p-7 lg:pt-7">
            <summary
              className={[
                // Strip the native triangle; the chevron is the affordance.
                "list-none [&::-webkit-details-marker]:hidden",
                "flex cursor-pointer items-start gap-2.5 rounded-xs",
                "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-(--color-gold)",
              ].join(" ")}
            >
              <Info
                size={16}
                className="mt-0.5 shrink-0 text-(--color-gold)"
                aria-hidden="true"
              />
              <p className="min-w-0 flex-1 text-sm leading-relaxed text-(--color-silver)">
                <strong className="font-semibold text-(--color-gold)">
                  A listing here is not a recommendation.
                </strong>{" "}
                Confirm hours and fees before you go.
              </p>
              <ChevronDown
                size={16}
                className="mt-0.5 shrink-0 text-(--color-silver) transition-transform duration-200 ease-out group-open:rotate-180 motion-reduce:transition-none"
                aria-hidden="true"
              />
            </summary>
            {/* Indented to the text column so it reads as the same thought
                continuing, not as a new block. */}
            <p className="mt-3 pl-6.5 text-sm leading-relaxed text-(--color-silver)">
              Being listed is not accreditation, endorsement, or any agreement
              with MetroPaws, unless marked{" "}
              <strong className="font-semibold text-(--color-surface)">
                MetroPaws Partner
              </strong>
              . Details on this page can go out of date, so treat them as a
              starting point rather than a confirmation.
            </p>
          </details>
        </div>
      </div>
    </section>
  );
}
