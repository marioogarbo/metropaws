/**
 * Google Play's four-colour glyph. Shared by the hero badge and the /download
 * page so the brand mark is defined once. Google's badge guidelines require the
 * official colours, so this icon deliberately ignores the MetroPaws palette.
 */
export function PlayStoreIcon() {
  return (
    <svg width="18" height="20" viewBox="0 0 18 20" fill="none" aria-hidden="true">
      <path
        d="M0.426 0.18C0.16.432 0 .826 0 1.337v17.326c0 .511.16.905.426 1.157l.06.058L10.104 10v-.178L.487.12z"
        fill="#4285F4"
      />
      <path
        d="M13.356 13.37l-3.252-3.37v-.178l3.252-3.37.073.042 3.855 2.19c1.1.625 1.1 1.649 0 2.274l-3.855 2.19z"
        fill="#FBBC04"
      />
      <path
        d="M13.43 13.328L10.104 10 0.426 19.82c.362.383.958.43 1.623.049L13.43 13.328z"
        fill="#EA4335"
      />
      <path
        d="M13.43 6.672L2.049.131C1.384-.25.788-.203.426.18L10.104 10z"
        fill="#34A853"
      />
    </svg>
  );
}
