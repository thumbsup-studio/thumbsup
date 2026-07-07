"use client";

import { useState } from "react";

import { BottomTabBar } from "@/features/home/components/bottom-tab-bar";
import { StreakBlock } from "@/features/home/components/streak-block";
import { TodayCourseCard } from "@/features/home/components/today-course-card";
import { WelcomeBlock } from "@/features/home/components/welcome-block";
import type { HomeData } from "@/features/home/types";

type HomePageProps = {
  data: HomeData;
  now: Date | string;
};

export function HomePage({ data, now }: HomePageProps) {
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const currentDate = typeof now === "string" ? new Date(now) : now;

  return (
    <main className="min-h-screen bg-[linear-gradient(180deg,#eef4ff_0%,#f7f9fc_38%,#eef2f8_100%)] px-4 py-6 text-slate-950 sm:px-6">
      <div className="mx-auto flex min-h-[calc(100vh-3rem)] w-full max-w-md flex-col gap-5">
        <div className="rounded-[36px] border border-slate-200/80 bg-[#f4f7fb] p-5 shadow-[0_24px_60px_rgba(15,23,42,0.10)]">
          <div className="space-y-5">
            <WelcomeBlock now={currentDate} />
            <StreakBlock streakDays={data.streakDays} />
            <TodayCourseCard
              course={data.todayCourse}
              onStart={() => {
                setStatusMessage("퀴즈는 준비 중입니다.");
              }}
            />
            {statusMessage ? (
              <p className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm font-medium text-amber-900">
                {statusMessage}
              </p>
            ) : null}
          </div>
        </div>

        <BottomTabBar
          onHistoryClick={() => {
            setStatusMessage("히스토리는 준비 중입니다.");
          }}
          onProfileClick={() => {
            setStatusMessage("프로필은 준비 중입니다.");
          }}
        />
      </div>
    </main>
  );
}
