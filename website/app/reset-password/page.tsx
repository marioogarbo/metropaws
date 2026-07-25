import { Suspense } from "react";
import ResetContent from "./reset-content";

export default function ResetPasswordPage() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Loading...</div>}>
      <ResetContent />
    </Suspense>
  );
}
