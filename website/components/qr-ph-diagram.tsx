/**
 * Wayfinding diagrams for the How to Pay page.
 *
 * These are deliberately diagrams, not screenshots. The checkout screen is
 * hosted by PayMongo, so a pixel screenshot would (a) go stale the moment they
 * redesign it and (b) publish a live, scannable QR Ph code on a public page.
 * Abstracting the amount as a bar also keeps the page free of a price claim
 * that would need updating whenever a plan changes.
 *
 * Label sizes are set so the smallest rendered text lands near 12px once the
 * viewBox is scaled down to its narrowest container. `--color-ink-faint` is a
 * divider colour (2.4:1) and never used for text here.
 */

/**
 * 9x9 stylised QR. Real finder patterns in three corners so it reads as a QR
 * at a glance; the remaining modules are a fixed decorative scatter. Hardcoded
 * rather than generated so server and client render the same markup.
 */
const QR_MODULES = [
  "###.#.###",
  "#.#...#.#",
  "###.#.###",
  "...#..#..",
  "#.#.##..#",
  "..#...##.",
  "###.#..#.",
  "#.#.##.##",
  "###..#.#.",
] as const;

const NAVY = "var(--color-navy)";
const GOLD = "var(--color-gold)";
const INK_MUTED = "var(--color-ink-muted)";
const INK_FAINT = "var(--color-ink-faint)";
const SURFACE = "var(--color-surface)";

function QrModules({ x, y, size }: { x: number; y: number; size: number }) {
  const moduleSize = size / QR_MODULES.length;

  return (
    <g>
      {QR_MODULES.map((row, rowIndex) =>
        row.split("").map((cell, columnIndex) =>
          cell === "#" ? (
            <rect
              key={`${rowIndex}-${columnIndex}`}
              x={x + columnIndex * moduleSize}
              y={y + rowIndex * moduleSize}
              width={moduleSize}
              height={moduleSize}
              style={{ fill: NAVY }}
            />
          ) : null,
        ),
      )}
    </g>
  );
}

/**
 * The checkout screen: total at the top, the countdown, then the QR Ph code.
 */
export function CheckoutScreenDiagram({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 260 400"
      className={className}
      role="img"
      aria-label="The checkout screen shows your total at the top, the time left to pay, and the QR Ph code underneath."
    >
      <rect
        x="1"
        y="1"
        width="258"
        height="398"
        rx="26"
        style={{ fill: SURFACE, stroke: INK_FAINT }}
        strokeWidth="1.5"
      />

      {/* Total due. The amount is a bar, not a figure: a number here would be a
          price claim to keep in sync with the plans. */}
      <text x="26" y="54" style={{ fill: INK_MUTED }} fontSize="14" fontWeight="500">
        Total due
      </text>
      <rect x="148" y="42" width="86" height="15" rx="4" style={{ fill: NAVY }} />

      <line
        x1="26"
        y1="80"
        x2="234"
        y2="80"
        style={{ stroke: INK_FAINT }}
        strokeWidth="1"
      />

      {/* Countdown */}
      <rect x="84" y="98" width="92" height="27" rx="13.5" style={{ fill: GOLD }} />
      <text
        x="130"
        y="116"
        textAnchor="middle"
        style={{ fill: NAVY }}
        fontSize="13"
        fontWeight="600"
      >
        Time left
      </text>

      {/* QR panel */}
      <rect
        x="34"
        y="146"
        width="192"
        height="192"
        rx="12"
        style={{ fill: "#fff", stroke: INK_FAINT }}
        strokeWidth="1.5"
      />
      <QrModules x={58} y={170} size={144} />

      <text
        x="130"
        y="370"
        textAnchor="middle"
        style={{ fill: INK_MUTED }}
        fontSize="14"
        fontWeight="600"
      >
        QR Ph
      </text>
    </svg>
  );
}

/**
 * The same-phone workaround: screenshot the code, then pick it from the gallery
 * inside the wallet app. This is the step text alone cannot carry.
 */
export function GalleryScanDiagram({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 236 138"
      className={className}
      role="img"
      aria-label="On one phone: screenshot the QR code, then in your wallet app choose Scan QR and pick that screenshot from your gallery."
    >
      {/* Left: the code on screen, being captured */}
      <rect
        x="1"
        y="1"
        width="88"
        height="112"
        rx="12"
        style={{ fill: SURFACE, stroke: INK_FAINT }}
        strokeWidth="1.5"
      />
      <QrModules x={23} y={26} size={44} />
      <rect
        x="14"
        y="17"
        width="62"
        height="62"
        rx="6"
        fill="none"
        style={{ stroke: GOLD }}
        strokeWidth="2"
        strokeDasharray="5 4"
      />
      <text
        x="45"
        y="132"
        textAnchor="middle"
        style={{ fill: INK_MUTED }}
        fontSize="13"
        fontWeight="600"
      >
        Screenshot
      </text>

      {/* Arrow */}
      <g style={{ stroke: NAVY }} strokeWidth="1.5" fill="none">
        <line x1="100" y1="57" x2="132" y2="57" />
        <polyline points="126,51 132,57 126,63" />
      </g>

      {/* Right: the wallet app picking it out of the gallery */}
      <rect
        x="147"
        y="1"
        width="88"
        height="112"
        rx="12"
        style={{ fill: SURFACE, stroke: INK_FAINT }}
        strokeWidth="1.5"
      />
      <rect
        x="163"
        y="20"
        width="56"
        height="48"
        rx="6"
        style={{ fill: "var(--color-cream-warm)", stroke: INK_FAINT }}
        strokeWidth="1"
      />
      <QrModules x={177} y={31} size={28} />
      <text
        x="191"
        y="90"
        textAnchor="middle"
        style={{ fill: INK_MUTED }}
        fontSize="13"
        fontWeight="600"
      >
        Scan QR
      </text>
      <text x="191" y="132" textAnchor="middle" style={{ fill: INK_MUTED }} fontSize="13">
        from gallery
      </text>
    </svg>
  );
}
