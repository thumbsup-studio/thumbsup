import { RequireAuth } from "@/features/auth/require-auth";
import { ProfileScreen } from "@/features/profile/components/profile-screen";

export const dynamic = "force-dynamic";

export default function Profile() {
  return (
    <RequireAuth>
      <ProfileScreen />
    </RequireAuth>
  );
}
