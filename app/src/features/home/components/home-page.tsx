"use client";

import { BottomTabBar } from "@/features/home/components/bottom-tab-bar";
import { StreakBlock } from "@/features/home/components/streak-block";
import { TodayCourseCard } from "@/features/home/components/today-course-card";
import { WelcomeBlock } from "@/features/home/components/welcome-block";
import type { HomeData } from "@/features/home/types";
import { useAppToast } from "@/providers/app-toast-provider";

type HomePageProps = {
  data: HomeData;
  now: Date | string;
};

export function HomePage({ data, now }: HomePageProps) {
  const { showToast } = useAppToast();
  const currentDate = typeof now === "string" ? new Date(now) : now;

  return (
    <main className="flex min-h-screen flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-5">
        <section className="rounded-card border border-border/80 bg-bg p-5 shadow-card">
          <div className="space-y-5">
            <div className="flex items-start justify-between gap-4">
              <WelcomeBlock now={currentDate} />
              <StreakBlock streakDays={data.streakDays} />
            </div>
          </div>
        </section>

        <TodayCourseCard
          course={data.todayCourse}
          onStart={() => {
            showToast({ message: "퀴즈는 준비 중입니다." });
          }}
        />

        <div className="mt-auto pt-1">
          <BottomTabBar
            activeTab="home"
            onHistoryClick={() => {
              showToast({ message: "히스토리는 준비 중입니다." });
            }}
            onProfileClick={() => {
              showToast({ message: "프로필은 준비 중입니다." });
            }}
          />
        </div>
      </div>
    </main>
  );
}
