import type { ServiceSlug } from "@/lib/directory-taxonomy";

/**
 * A listing in the public pet-care directory.
 *
 * A community resource, not a partner network: `is_partner` only changes the
 * card's badge and does not imply any agreement with MetroPaws. Deliberately
 * unrelated to the reimbursement providers on `/admin/providers`, which carry
 * payout details and are never exposed publicly.
 */
export type DirectoryProvider = {
  id: string;
  name: string;
  services: ServiceSlug[];
  address: string | null;
  phone: string | null;
  email: string | null;
  website: string | null;
  hours: string | null;
  map_url: string | null;
  is_partner: boolean;
  is_published: boolean;
};
