import { cn } from "@/lib/utils";

const ROWS = [0, 1, 2, 3, 4, 5, 6];
// Widths echo the real tab labels (All / To review / Approved / Paid / Rejected)
// so the skeleton doesn't read as a mechanical row of identical chips.
const TAB_WIDTHS = ["w-16", "w-28", "w-28", "w-20", "w-24"];

function Bar({ className }: { className: string }) {
  return <div className={cn("bg-[oklch(0.90_0.010_258)] rounded", className)} />;
}

export default function Loading() {
  return (
    <main className="max-w-7xl mx-auto px-6 py-10 animate-pulse motion-reduce:animate-none">
      <header className="mb-8 flex flex-col sm:flex-row sm:items-start sm:justify-between gap-5">
        <div>
          <Bar className="h-3 w-28 mb-2.5" />
          <Bar className="h-7 w-52" />
        </div>
        <Bar className="h-9 w-36 rounded-lg" />
      </header>

      <div className="space-y-4">
        <div className="flex flex-col sm:flex-row gap-3 sm:items-center sm:justify-between">
          <div className="flex gap-1 flex-wrap">
            {TAB_WIDTHS.map((w, i) => (
              <Bar key={i} className={`h-8 ${w} rounded-lg`} />
            ))}
          </div>
          <Bar className="h-9 w-full sm:w-64 rounded-lg" />
        </div>

        <div className="rounded-xl border border-[oklch(0.88_0.010_258)] overflow-hidden bg-[oklch(0.99_0.005_80)]">
          <div className="h-10 border-b border-[oklch(0.89_0.014_258)] bg-[oklch(0.94_0.013_258)]" />
          {ROWS.map((i) => (
            <div
              key={i}
              className="flex items-center gap-4 px-4 py-3.5 border-b border-[oklch(0.92_0.010_258)] last:border-b-0"
            >
              <div className="w-8 h-8 rounded-full bg-[oklch(0.90_0.010_258)] shrink-0" />
              <div className="flex-1 min-w-0 space-y-1.5">
                <Bar className="h-3.5 w-40 max-w-full" />
                <Bar className="h-2.5 w-24 bg-[oklch(0.93_0.008_258)]" />
              </div>
              <Bar className="hidden md:block h-3.5 w-32" />
              <Bar className="h-3.5 w-20" />
              <Bar className="h-6 w-24 rounded-full" />
              <Bar className="hidden lg:block h-3.5 w-28" />
              <Bar className="h-7 w-20 rounded-lg" />
            </div>
          ))}
        </div>
      </div>
    </main>
  );
}
