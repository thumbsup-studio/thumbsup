import { RequireAuth } from "@/features/auth/require-auth";
import { CoursesIndexScreen } from "@/features/authoring/components/courses-index-screen";

export const dynamic = "force-dynamic";

export default function AuthoringQuizzesPage() {
  return (
    <RequireAuth>
      <CoursesIndexScreen />
    </RequireAuth>
  );
}
