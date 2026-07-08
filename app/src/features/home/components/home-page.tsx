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
    <main className="min-h-screen bg-[linear-gradient(180deg,#eef4ff_0%,#f7f9fc_38%,#eef2f8_100%)] px-4 py-6 text-slate-950 sm:px-6">
      <div className="mx-auto w-full max-w-md">
        <div className="flex min-h-[calc(100vh-3rem)] flex-col rounded-[36px] border border-slate-200/80 bg-[#f4f7fb] p-5 shadow-[0_24px_60px_rgba(15,23,42,0.10)]">
          <div className="space-y-5">
            <div className="flex items-start justify-between gap-4 pt-4">
              <WelcomeBlock now={currentDate} />
              <StreakBlock streakDays={data.streakDays} />
            </div>
            <TodayCourseCard
              course={data.todayCourse}
              onStart={() => {
                showToast({ message: "퀴즈는 준비 중입니다." });
              }}
            />
          </div>

          <div className="mt-auto pt-5">
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
      </div>
    </main>
  );
}
