/**
 * Canonical service vocabulary for the pet-care directory.
 *
 * MIRRORED IN `backend/directory_taxonomy.py`, which validates writes against
 * the same slugs. Adding a service means editing BOTH files: the backend would
 * reject a slug it doesn't know, and a slug no filter group claims would
 * silently vanish from every chip on the page.
 *
 * A listing stores a LIST of these rather than the free-text category line the
 * client supplies ("Veterinary / Grooming / Boarding / Supplies"), so a place
 * that is both a clinic and a groomer surfaces under both filters.
 */

export const SERVICE_LABELS = {
  veterinary: "Veterinary",
  animal_hospital: "Animal Hospital",
  emergency: "Emergency",
  diagnostics: "Diagnostics",
  surgery: "Surgery",
  grooming: "Grooming",
  boarding: "Boarding",
  pet_hotel: "Pet Hotel",
  pet_store: "Pet Store",
  pet_supplies: "Pet Supplies",
} as const;

export type ServiceSlug = keyof typeof SERVICE_LABELS;

export const SERVICE_SLUGS = Object.keys(SERVICE_LABELS) as ServiceSlug[];

/**
 * The filter chips, in display order. Each gathers several slugs so a visitor
 * looking for "somewhere to board the cat" finds pet hotels too.
 */
export const SERVICE_FILTERS = [
  {
    id: "veterinary",
    label: "Veterinary",
    slugs: [
      "veterinary",
      "animal_hospital",
      "emergency",
      "diagnostics",
      "surgery",
    ],
  },
  { id: "grooming", label: "Grooming", slugs: ["grooming"] },
  { id: "stores", label: "Pet Stores", slugs: ["pet_store", "pet_supplies"] },
  { id: "boarding", label: "Boarding", slugs: ["boarding", "pet_hotel"] },
] as const satisfies ReadonlyArray<{
  id: string;
  label: string;
  slugs: ReadonlyArray<ServiceSlug>;
}>;

export type ServiceFilterId = (typeof SERVICE_FILTERS)[number]["id"];

/** The chip set as the page uses it: the service groups, plus the unfiltered view. */
export type DirectoryFilterId = ServiceFilterId | "all";

export function serviceLabel(slug: ServiceSlug): string {
  return SERVICE_LABELS[slug];
}

/** The card's category line, e.g. "Veterinary / Diagnostics / Surgery". */
export function serviceLine(services: ServiceSlug[]): string {
  return services.map(serviceLabel).join(" / ");
}

/** The slugs a chip covers, widened so callers can test arbitrary slugs. */
export function filterSlugs(filterId: ServiceFilterId): ReadonlyArray<string> {
  return SERVICE_FILTERS.find((f) => f.id === filterId)?.slugs ?? [];
}

export function matchesFilter(
  services: ServiceSlug[],
  filterId: ServiceFilterId,
): boolean {
  const slugs = filterSlugs(filterId);
  return services.some((slug) => slugs.includes(slug));
}

/**
 * The group a listing leads with: the first stored service that a chip claims.
 *
 * `services` keeps the order the admin typed it, which is the order the business
 * itself leads with — "Mighty Waggers Pet Supplies & Pet Grooming" stores
 * `pet_supplies` first, "Petunia Veterinary Clinic" stores `veterinary` first.
 * So reordering the list in admin changes which mark the row carries, which is
 * the right lever to hand an operator who disagrees with the pick.
 *
 * Null only if a listing carries slugs no chip covers, which the taxonomy is
 * built to prevent.
 */
export function primaryFilter(services: ServiceSlug[]): ServiceFilterId | null {
  for (const slug of services) {
    const filter = SERVICE_FILTERS.find((f) => filterSlugs(f.id).includes(slug));
    if (filter) return filter.id;
  }
  return null;
}
