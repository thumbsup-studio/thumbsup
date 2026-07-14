import { redirect } from "next/navigation";
import { RequireAuth } from "@/features/auth/require-auth";
import { JobScreen } from "@/features/authoring/components/job-screen";

export const dynamic = "force-dynamic";

type JobRouteProps = {
  params: Promise<{ jobId: string }>;
};

export default async function AuthoringJobPage({ params }: JobRouteProps) {
  const { jobId } = await params;
  const parsedJobId = Number(jobId);

  // 잘못된 잡 id로 직접 진입하면 목록으로 돌려보낸다(방어).
  if (!Number.isInteger(parsedJobId) || parsedJobId <= 0) {
    redirect("/authoring");
  }

  return (
    <RequireAuth>
      <JobScreen jobId={parsedJobId} />
    </RequireAuth>
  );
}
