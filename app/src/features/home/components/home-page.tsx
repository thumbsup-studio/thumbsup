"use client";

import { useState } from "react";
import { AppTabBar } from "@/components/app-tab-bar";
import { HelpCircleIcon } from "@/components/icons";
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
  const [listRuleOpen, setListRuleOpen] = useState(false);

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
          {/* 카드마다 칩으로 반복하는 대신 섹션 제목 하나로 목록 성격을 알린다. */}
          <div className="flex items-center">
            {/* 시각 크기는 h1(WelcomeBlock text-2xl)급, 문서 아웃라인상으론 h1 아래 섹션이라 h2 유지. */}
            <h2 className="text-2xl font-semibold tracking-tight" id="recent-courses-heading">
              최근 학습 코스
            </h2>
            {/* 데스크톱은 호버·포커스, 터치는 탭 토글로 목록 규칙을 안내한다. */}
            <span className="relative flex items-center">
              <button
                aria-expanded={listRuleOpen}
                aria-label="최근 학습 코스 안내"
                className="flex size-11 items-center justify-center text-ink-muted"
                onBlur={() => setListRuleOpen(false)}
                onClick={() => setListRuleOpen((open) => !open)}
                onFocus={() => setListRuleOpen(true)}
                onMouseEnter={() => setListRuleOpen(true)}
                onMouseLeave={() => setListRuleOpen(false)}
                type="button"
              >
                <HelpCircleIcon aria-hidden="true" className="size-5" />
              </button>
              {/* 아이콘 오른쪽에 절대배치 — 레이아웃 흐름 밖이라 뜨고 닫혀도 행이 덜컹이지 않는다. */}
              {listRuleOpen && (
                <span
                  className="absolute left-full top-1/2 z-10 w-max -translate-y-1/2 rounded-control border border-border bg-surface px-3 py-2 text-xs text-ink shadow-card"
                  role="status"
                >
                  최근에 푼 순서로 최대 10개까지 보여드려요.
                  <br />
                  전체 코스는 하단의 코스 탭에서 볼 수 있어요.
                </span>
              )}
            </span>
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
