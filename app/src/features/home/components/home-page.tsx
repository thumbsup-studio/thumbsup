"use client";

import { AppTabBar } from "@/components/app-tab-bar";
import { CharacterBlock } from "@/features/home/components/character-block";
import { CourseCarousel } from "@/features/home/components/course-carousel";
import { StreakBlock } from "@/features/home/components/streak-block";
import { WelcomeBlock } from "@/features/home/components/welcome-block";
import type { HomeData } from "@/features/home/types";

type HomePageProps = {
  data: HomeData;
  now: Date | string;
};

export function HomePage({ data, now }: HomePageProps) {
  const currentDate = typeof now === "string" ? new Date(now) : now;

  return (
    <main className="flex min-h-dvh flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-5">
        <section className="rounded-card border border-border/80 bg-bg p-5 shadow-card">
          <div className="space-y-5">
            <div className="flex items-start justify-between gap-4">
              <WelcomeBlock now={currentDate} />
              <StreakBlock streakDays={data.streakDays} />
            </div>
          </div>
        </section>

        <CharacterBlock name={data.character.name} fullness={data.character.fullness} />

        <section aria-labelledby="recent-courses-heading" className="space-y-3">
          <div>
            {/* 시각 크기는 h1(WelcomeBlock text-2xl)급, 문서 아웃라인상으론 h1 아래 섹션이라 h2 유지. */}
            <h2 className="text-2xl font-semibold tracking-tight" id="recent-courses-heading">
              최근 학습 코스
            </h2>
            <p className="mt-1 text-sm font-medium text-ink-muted">
              최근에 푼 순서로 최대 10개까지 보여드려요.
              <br />
              전체 코스는 하단의 코스 탭에서 볼 수 있어요.
            </p>
          </div>
          <CourseCarousel courses={data.courses} />
        </section>

        <div className="sticky bottom-4 mt-auto pt-1">
          <AppTabBar activeTab="home" />
        </div>
      </div>
    </main>
  );
}
