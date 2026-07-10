import { Skeleton } from "@/components/ui/skeleton";

/** 프로필 로딩 골격 — 신원 카드 + 설정 리스트 레이아웃을 본뜬다. */
export function ProfileSkeleton() {
  return (
    <main className="flex min-h-screen flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div
        aria-busy="true"
        aria-label="프로필 불러오는 중"
        className="mx-auto flex w-full max-w-md flex-1 flex-col gap-4"
        role="status"
      >
        <section className="flex flex-col items-center gap-3 rounded-card border border-border/80 bg-surface p-6 shadow-card">
          <Skeleton className="size-22 rounded-chip" />
          <Skeleton className="h-5 w-48" />
        </section>
        <section className="flex flex-col gap-2 rounded-card border border-border/80 bg-surface p-2 shadow-card">
          <Skeleton className="h-13 w-full" />
          <Skeleton className="h-13 w-full" />
          <Skeleton className="h-13 w-full" />
        </section>
      </div>
    </main>
  );
}
