import { SiteHeader } from "@/components/site-header";
import { HeroSection } from "@/components/hero-section";
import { LogoMarquee } from "@/components/logo-marquee";
import { AppPreviewSection } from "@/components/app-preview-section";
import { HowItWorksSection } from "@/components/how-it-works-section";
import { CoverageTeaser } from "@/components/coverage-teaser";
import { PlansSection } from "@/components/plans-section";
import { PawPointsSection } from "@/components/pawpoints-section";
import { CommunitySection } from "@/components/community-section";
import { FoundingSection } from "@/components/founding-section";
import { FaqSection } from "@/components/faq-section";
import { SiteFooter } from "@/components/site-footer";
import { PartnerClinicCta } from "@/components/partner-clinic-cta";

export default function Home() {
  return (
    <div className="flex flex-col min-h-svh overflow-x-clip">
      <SiteHeader />
      <main className="flex flex-col flex-1">
        <HeroSection />
        <LogoMarquee />
        <AppPreviewSection />
        <HowItWorksSection />
        <CoverageTeaser />
        <PlansSection />
        <PawPointsSection />
        <CommunitySection />
        <FoundingSection />
        <FaqSection />
        <PartnerClinicCta />
      </main>

      <SiteFooter variant="photo" />
    </div>
  );
}
