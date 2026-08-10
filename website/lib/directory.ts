import type { DirectoryProvider } from "@/types/directory";
import { fetchPublicContent } from "@/lib/public-content";

/** A phone field needs at least this many digits before we offer to dial it. */
const MIN_DIALABLE_DIGITS = 7;

export type DirectoryResult =
  | { ok: true; providers: DirectoryProvider[] }
  | { ok: false; providers: [] };

/**
 * Fetch the published directory.
 *
 * Unlike `faq-section.tsx` and `plans-section.tsx`, a failure here does NOT
 * fall back to a hardcoded copy of the listings. Those two ship stable
 * marketing copy; this page ships clinics' phone numbers and opening hours,
 * which go stale the moment an admin edits a row. Handing a visitor a stale
 * number for an emergency vet is worse than telling them the list is
 * temporarily unavailable, so the caller renders an error state instead.
 *
 * Having no fallback also makes a failure here visible in a way the FAQ and plan
 * sections' failures are not, which is what `app/api/directory/route.ts` and
 * `components/directory-recovery.tsx` exist to catch: a page prerendered from a
 * failure would otherwise be served to everyone for the rest of its revalidate
 * window.
 */
export async function fetchDirectory(): Promise<DirectoryResult> {
  const response = await fetchPublicContent("/directory");
  if (!response) return { ok: false, providers: [] };

  try {
    const data = (await response.json()) as DirectoryProvider[];
    if (!Array.isArray(data)) return { ok: false, providers: [] };
    return { ok: true, providers: data };
  } catch {
    return { ok: false, providers: [] };
  }
}

/**
 * Where the "View map" button goes.
 *
 * An admin can paste an exact Google Maps pin, but hunting one down for every
 * listing is work nobody will do, so a name + address search stands in. Both
 * land the visitor on the same map; only the precision differs.
 */
export function mapUrl(provider: DirectoryProvider): string | null {
  if (provider.map_url) return provider.map_url;
  if (!provider.address) return null;
  const query = encodeURIComponent(`${provider.name}, ${provider.address}`);
  return `https://www.google.com/maps/search/?api=1&query=${query}`;
}

/**
 * The `tel:` target for a phone field, or null when the field holds prose.
 *
 * Some listings carry "Please verify directly with the clinic" where a number
 * would go. That is the honest state of the data and is shown as written, but
 * it must never become a tappable link. Where several numbers are listed, the
 * first one is the one that dials.
 */
export function telHref(phone: string | null): string | null {
  if (!phone) return null;
  const first = phone.split("/")[0];
  const digits = first.replace(/\D/g, "");
  if (digits.length < MIN_DIALABLE_DIGITS) return null;
  return `tel:${first.trim().startsWith("+") ? "+" : ""}${digits}`;
}

/**
 * True when a field holds an apology instead of data.
 *
 * Three seed listings carry "Please verify before visiting" where opening hours
 * belong and "Please verify directly with the clinic" where a number belongs.
 * That is the honest state of the data, but printed as written a single row
 * says almost the same sentence twice, in two different wordings, and neither
 * tells the reader anything they could act on. The row uses this to say what is
 * missing once, and to point at the map listing instead.
 */
export function isUnverified(value: string | null): boolean {
  if (!value) return false;
  return /please\s+(verify|confirm|check)/i.test(value);
}

/** Strip the scheme so a website reads as a domain rather than a URL. */
export function websiteLabel(url: string): string {
  return url.replace(/^https?:\/\//, "").replace(/\/$/, "");
}
