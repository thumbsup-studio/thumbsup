import { RequireAuth } from "@/features/auth/require-auth";
import { HomeScreen } from "@/features/home/components/home-screen";

export const dynamic = "force-dynamic";

export default function Home() {
  return (
    <RequireAuth>
      <HomeScreen />
    </RequireAuth>
  );
}
