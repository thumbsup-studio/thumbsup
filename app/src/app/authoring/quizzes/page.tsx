import { RequireAuth } from "@/features/auth/require-auth";
import { QuizzesScreen } from "@/features/authoring/components/quizzes-screen";

export const dynamic = "force-dynamic";

export default function AuthoringQuizzesPage() {
  return (
    <RequireAuth>
      <QuizzesScreen />
    </RequireAuth>
  );
}
