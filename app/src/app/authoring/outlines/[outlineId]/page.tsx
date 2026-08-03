import { redirect } from "next/navigation";
import { RequireAuth } from "@/features/auth/require-auth";
import { OutlineDetailScreen } from "@/features/authoring/components/outline-detail-screen";

export const dynamic = "force-dynamic";

type OutlineRouteProps = {
  params: Promise<{ outlineId: string }>;
};

export default async function AuthoringOutlinePage({ params }: OutlineRouteProps) {
  const { outlineId } = await params;
  const parsedOutlineId = Number(outlineId);

  if (!Number.isInteger(parsedOutlineId) || parsedOutlineId <= 0) {
    redirect("/authoring/outlines");
  }

  return (
    <RequireAuth>
      <OutlineDetailScreen outlineId={parsedOutlineId} />
    </RequireAuth>
  );
}
