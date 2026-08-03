import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { DocumentUnderRevision } from "@/components/document-under-revision";
import { MANUAL_UNDER_REVISION, MEMBER_MANUAL_PATH } from "@/lib/legal-documents";

// Exists only to answer /docs/member-manual.pdf while the manual is under
// revision — next.config.ts rewrites the PDF path here. The Android app links to
// that path from its Account section, so it has to keep resolving.
export const metadata: Metadata = {
  title: "Member Manual | MetroPaws Wellness Club",
  description:
    "Our Member Manual is being updated. The revised version will be published here.",
  robots: { index: false, follow: true },
};

export default function MemberManualNoticePage() {
  // With the manual restored, the rewrite is gone and this page has nothing to
  // say — send anyone on a stale link to the real PDF.
  if (!MANUAL_UNDER_REVISION) {
    redirect(MEMBER_MANUAL_PATH);
  }

  return <DocumentUnderRevision documentName="Member Manual" />;
}
