import { RequireAuth } from "@/features/auth/require-auth";
import { OutlinesScreen } from "@/features/authoring/components/outlines-screen";

export const dynamic = "force-dynamic";

export default function AuthoringOutlinesPage() {
  return (
    <RequireAuth>
      <OutlinesScreen />
    </RequireAuth>
  );
}
