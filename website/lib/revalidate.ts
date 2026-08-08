import { revalidatePath } from "next/cache";

/**
 * Revalidate an admin page and the public homepage together.
 *
 * FAQs and plans are fetched by the homepage with `next: { revalidate: 3600 }`,
 * so without an explicit purge an admin edit stayed invisible to visitors for
 * up to an hour. Editors read that delay as a broken save and edit again.
 *
 * Call this instead of `revalidatePath` from any admin action whose data is
 * rendered on a public page.
 */
export function revalidateAdminAndHome(adminPath: string): void {
  revalidateAdminAndPublic(adminPath, "/");
}

/**
 * Same idea for admin data that feeds a public page other than the homepage.
 *
 * The pet-care directory renders on `/find-pet-care`, which is not the
 * homepage, so purging `/` alone would leave an admin edit invisible for the
 * full hour of the ISR window.
 */
export function revalidateAdminAndPublic(
  adminPath: string,
  ...publicPaths: string[]
): void {
  revalidatePath(adminPath);
  for (const path of publicPaths) {
    revalidatePath(path);
  }
}
