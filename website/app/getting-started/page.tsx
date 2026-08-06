import type { Metadata } from "next";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { GettingStartedHero } from "@/components/getting-started-hero";
import { GettingStartedSteps } from "@/components/getting-started-steps";
import {
  GettingStartedHelp,
  GettingStartedCta,
} from "@/components/getting-started-help";

export const metadata: Metadata = {
  title: "Getting Started | MetroPaws Wellness Club",
  description:
    "Create your MetroPaws account, add your pet, choose a plan, and pay by scanning one QR Ph code with GCash, Maya, BPI, GoTyme, Home Credit, or any Philippine bank app. No card required.",
};

export default function GettingStartedPage() {
  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-col flex-1">
        <GettingStartedHero />
        <GettingStartedSteps />
        <GettingStartedHelp />
        <GettingStartedCta />
      </main>
      <SiteFooter variant="photo" />
    </div>
  );
}
