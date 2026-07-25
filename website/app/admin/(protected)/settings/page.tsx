import { Settings } from "lucide-react";
import { fetchSettingsAction } from "./actions";
import { SettingsPanel } from "@/components/admin/settings-panel";

export default async function AdminSettingsPage() {
  const settings = await fetchSettingsAction();

  return (
    <main className="max-w-3xl mx-auto px-6 py-12 flex flex-col gap-10">
      <div>
        <div className="flex items-center gap-2.5 mb-1.5">
          <Settings size={15} className="text-[oklch(0.48_0.020_258)]" />
          <h1 className="text-base text-[oklch(0.24_0.055_258)] font-semibold">
            Settings
          </h1>
        </div>
        <p className="text-sm text-[oklch(0.48_0.020_258)]">
          Enrollment controls and membership configuration.
        </p>
      </div>

      <SettingsPanel initialSettings={settings} />
    </main>
  );
}
