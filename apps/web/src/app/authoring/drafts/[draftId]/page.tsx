import { redirect } from "next/navigation";
import { RequireAuth } from "@/features/auth/require-auth";
import { DraftDetailScreen } from "@/features/authoring/components/draft-detail-screen";

export const dynamic = "force-dynamic";

type DraftRouteProps = {
  params: Promise<{ draftId: string }>;
};

export default async function AuthoringDraftPage({ params }: DraftRouteProps) {
  const { draftId } = await params;
  const parsedDraftId = Number(draftId);

  // 잘못된 draft id로 직접 진입하면 목록으로 돌려보낸다(방어).
  if (!Number.isInteger(parsedDraftId) || parsedDraftId <= 0) {
    redirect("/authoring");
  }

  return (
    <RequireAuth>
      <DraftDetailScreen draftId={parsedDraftId} />
    </RequireAuth>
  );
}
