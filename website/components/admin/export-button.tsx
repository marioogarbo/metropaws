"use client";

import { useState } from "react";
import { Download, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";

type ExportResource = "members" | "reimbursements" | "reservations";

interface ExportButtonProps {
  resource: ExportResource;
}

function filenameFromDisposition(disposition: string | null): string | null {
  const match = disposition?.match(/filename="([^"]+)"/);
  return match ? match[1] : null;
}

export function ExportButton({ resource }: ExportButtonProps) {
  const [isExporting, setIsExporting] = useState(false);

  async function handleExport() {
    setIsExporting(true);
    try {
      const res = await fetch(`/api/admin/export/${resource}`);
      if (!res.ok) throw new Error(`Export failed with status ${res.status}`);

      const blob = await res.blob();
      const filename =
        filenameFromDisposition(res.headers.get("Content-Disposition")) ??
        `${resource}.xlsx`;

      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = filename;
      link.click();
      URL.revokeObjectURL(url);
    } catch {
      toast.error("Export failed. Please try again.");
    } finally {
      setIsExporting(false);
    }
  }

  return (
    <Button
      variant="outline"
      onClick={handleExport}
      disabled={isExporting}
      className="text-[oklch(0.24_0.055_258)] border-[oklch(0.91_0.010_258)] hover:bg-[oklch(0.97_0.008_80)]"
    >
      {isExporting ? <Loader2 className="animate-spin" /> : <Download />}
      Export to Excel
    </Button>
  );
}
