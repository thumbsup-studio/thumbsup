import { Skeleton } from "@/components/ui/skeleton";

/** 홈 데이터 로딩 중 골격 — HomePage 레이아웃(환영·스트릭 카드 + 오늘의 학습 카드)을 본뜬다. */
export function HomeSkeleton() {
  return (
    <main className="flex min-h-screen flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div
        aria-busy="true"
        aria-label="홈 불러오는 중"
        className="mx-auto flex w-full max-w-md flex-1 flex-col gap-5"
        role="status"
      >
        <section className="rounded-card border border-border/80 bg-bg p-5 shadow-card">
          <div className="flex items-start justify-between gap-4">
            <div className="min-w-0 flex-1 space-y-3">
              <Skeleton className="h-7 w-40" />
              <Skeleton className="h-7 w-28" />
            </div>
            <Skeleton className="h-16 w-24 rounded-card" />
          </div>
        </section>

        <section className="rounded-card bg-primary px-6 py-6 shadow-hero">
          <Skeleton className="h-6 w-20 rounded-chip" />
          <div className="mt-5 space-y-2">
            <Skeleton className="h-4 w-24" />
            <Skeleton className="h-8 w-44" />
          </div>
          <div className="mt-6 flex items-center justify-between">
            <Skeleton className="h-4 w-10" />
            <Skeleton className="h-4 w-24" />
          </div>
          <Skeleton className="mt-6 h-12 w-full" />
        </section>
      </div>
    </main>
  );
}
