import { RequireAuth } from "@/features/auth/require-auth";
import { HomePage } from "@/features/home/components/home-page";
import { mockHomeData } from "@/features/home/mock-home-data";

export const dynamic = "force-dynamic";

export default function Home() {
  return (
    <>
      <RequireAuth />
      <HomePage data={mockHomeData} now={new Date().toISOString()} />
    </>
  );
}
