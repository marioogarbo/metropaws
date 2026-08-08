import {
  BedDouble,
  PawPrint,
  Scissors,
  ShoppingBag,
  Stethoscope,
  type LucideIcon,
} from "lucide-react";
import { cn } from "@/lib/utils";
import {
  primaryFilter,
  type DirectoryFilterId,
  type ServiceFilterId,
  type ServiceSlug,
} from "@/lib/directory-taxonomy";

/**
 * One mark per filter group, and only per filter group.
 *
 * The alternative was each business's own logo. That was rejected: the listings
 * are published without the businesses' consent (they are public contact
 * details, which is ordinary directory practice), and reproducing a trademark
 * beside a gold "MetroPaws Partner" tier reads as exactly the affiliation the
 * hero disclaimer spends a paragraph denying. Nineteen sourced-from-Facebook
 * images would also arrive at nineteen different densities, croppings, and
 * backgrounds, which destroys the one thing a row-start image is for: a
 * consistent rail the eye can run down.
 *
 * Four owned silhouettes do the scanning job instead. In a list where ten of
 * nineteen rows are clinics, the two scissors and the two beds are what the eye
 * catches.
 */
const SERVICE_ICONS: Record<ServiceFilterId, LucideIcon> = {
  veterinary: Stethoscope,
  grooming: Scissors,
  stores: ShoppingBag,
  boarding: BedDouble,
};

/**
 * `BedDouble` over `House` for boarding, because a house glyph in a website's
 * chrome reads as "home page" first. `ShoppingBag` over `Store` because a store
 * front shares its roofline with the bed and the house, and silhouette is the
 * whole point at this size.
 *
 * Null for "All", which is the absence of a service filter rather than a fifth
 * one. A paw print was tried there and lost twice: it says nothing the other
 * four don't, and its toes collapse into a smudge at chip size.
 */
export function filterIcon(filterId: DirectoryFilterId): LucideIcon | null {
  return filterId === "all" ? null : SERVICE_ICONS[filterId];
}

/**
 * The listing's mark, sized to sit beside the name rather than above it.
 *
 * Decorative by construction: the service tags directly below spell out the
 * same thing in words, and the filter chip that taught the glyph carries its
 * label. Nothing here is the only carrier of any fact, so it stays out of the
 * accessibility tree.
 */
export function ServiceMark({ services }: { services: ServiceSlug[] }) {
  const filter = primaryFilter(services);
  // PawPrint only as the defensive fallback for a slug no chip claims, which
  // the taxonomy is built to prevent. At tile size its toes still resolve.
  const Icon = filter ? SERVICE_ICONS[filter] : PawPrint;

  return (
    <span
      aria-hidden="true"
      className={cn(
        // rounded-lg, the radius of the search field and the chips, so the mark
        // reads as part of the same vocabulary as the control that produced it.
        "mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-lg md:size-10",
        "bg-(--color-navy-wash) text-(--color-navy)",
        "group-hover:bg-(--color-navy-wash-hover) group-focus-within:bg-(--color-navy-wash-hover)",
        "transition-colors duration-150 motion-reduce:transition-none",
      )}
    >
      {/* Stroke 2, not the 1.75 the inline detail icons use. Those are read at
          reading distance; this one has to register in peripheral vision while
          the eye runs down the rail, and 1.75 at 18px was too light to. */}
      <Icon size={18} strokeWidth={2} />
    </span>
  );
}
