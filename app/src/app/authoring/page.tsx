import { RequireAuth } from "@/features/auth/require-auth";
import { DraftsScreen } from "@/features/authoring/components/drafts-screen";

export const dynamic = "force-dynamic";

export default function AuthoringDraftsPage() {
  return (
    <RequireAuth>
      <DraftsScreen />
    </RequireAuth>
  );
}
