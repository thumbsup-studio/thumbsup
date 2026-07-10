import { RequireAuth } from "@/features/auth/require-auth";
import { PlayPage } from "@/features/play/components/play-page";

export const dynamic = "force-dynamic";

export default function Play() {
  return (
    <RequireAuth>
      <PlayPage />
    </RequireAuth>
  );
}
