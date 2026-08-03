import { RequireAuth } from "@/features/auth/require-auth";
import { CoursePage } from "@/features/course/components/course-page";

export const dynamic = "force-dynamic";

export default function Course() {
  return (
    <RequireAuth>
      <CoursePage />
    </RequireAuth>
  );
}
