import { redirect } from "next/navigation";
import { RequireAuth } from "@/features/auth/require-auth";
import { CourseQuizzesScreen } from "@/features/authoring/components/course-quizzes-screen";

export const dynamic = "force-dynamic";

type CourseRouteProps = {
  params: Promise<{ course: string }>;
};

export default async function AuthoringCoursePage({ params }: CourseRouteProps) {
  const { course } = await params;
  const courseId = Number(course);

  // 잘못된 course id로 직접 진입하면 코스 인덱스로 돌려보낸다(방어).
  if (!Number.isInteger(courseId) || courseId <= 0) {
    redirect("/authoring/quizzes");
  }

  return (
    <RequireAuth>
      <CourseQuizzesScreen courseId={courseId} />
    </RequireAuth>
  );
}
