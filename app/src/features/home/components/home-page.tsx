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

        <CourseCarousel courses={data.courses} completed={data.todayCompleted} />

        <div className="sticky bottom-4 mt-auto pt-1">
          <AppTabBar activeTab="home" />
        </div>
      </div>
    </main>
  );
}
