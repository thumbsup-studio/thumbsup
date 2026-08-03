"use client";

import { useEffect, useRef, useState } from "react";
import { ChevronLeftIcon, ChevronRightIcon } from "@/components/icons";
import { Button } from "@/components/ui/button";
import { RecentCourseCard } from "@/features/home/components/recent-course-card";
import type { HomeCourse } from "@/features/home/types";

type CourseCarouselProps = {
  courses: HomeCourse[];
};

/**
 * 학습 중인 코스 캐러셀(#23) — 서버가 최근 푼 순으로 준 목록을 좌우 스크롤 스냅으로 넘겨 본다.
 * 스와이프 외에 좌우 화살표 버튼으로도 전환할 수 있다(TC-23-26).
 * 코스가 1개면 스냅 컨테이너·인디케이터 없이 단일 카드로 렌더한다(TC-23-06).
 * 현재 위치는 IntersectionObserver로 추적해 점 인디케이터와 스크린리더 문구를 갱신한다.
 */
export function CourseCarousel({ courses }: CourseCarouselProps) {
  const listRef = useRef<HTMLUListElement>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const multiple = courses.length > 1;

  useEffect(() => {
    // courses가 바뀌면(개수·내용) 옵저버를 새로 건다 — 이전 슬라이드만 관찰하는 stale 옵저버 방지.
    if (courses.length < 2) {
      return;
    }
    const list = listRef.current;
    if (!list) {
      return;
    }
    const slides = Array.from(list.children);
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            setActiveIndex(slides.indexOf(entry.target));
          }
        }
      },
      { root: list, threshold: 0.6 },
    );
    for (const slide of slides) {
      observer.observe(slide);
    }
    return () => observer.disconnect();
  }, [courses]);

  const scrollToIndex = (index: number) => {
    const list = listRef.current;
    const slide = list?.children[index];
    if (!list || !(slide instanceof HTMLElement)) {
      return;
    }
    // 전환 애니메이션은 ul의 motion-safe:scroll-smooth가 담당한다.
    // offsetLeft는 positioned 조상 기준이라 리스트 자신의 좌표를 빼야 리스트 내 상대 위치가 된다.
    list.scrollTo({ left: slide.offsetLeft - list.offsetLeft });
  };

  const first = courses[0];
  if (!first) {
    return null; // 서버가 최소 1개를 보장하지만(이슈 240), 타입 좁히기용 방어
  }

  if (!multiple) {
    return <RecentCourseCard course={first} />;
  }

  return (
    // 섹션 제목("최근 학습 코스")과 landmark는 HomePage 쪽 section이 제공한다.
    <div>
      <ul
        className="scrollbar-hidden flex snap-x snap-mandatory gap-3 overflow-x-auto motion-safe:scroll-smooth"
        ref={listRef}
      >
        {courses.map((course) => (
          <li className="w-full shrink-0 snap-center" key={course.courseId}>
            <RecentCourseCard course={course} />
          </li>
        ))}
      </ul>
      <div className="mt-1 flex items-center justify-center gap-2">
        <Button
          aria-label="이전 코스"
          className="min-w-12 px-0"
          disabled={activeIndex === 0}
          onClick={() => scrollToIndex(activeIndex - 1)}
          variant="ghost"
        >
          <ChevronLeftIcon aria-hidden="true" className="size-5" />
        </Button>
        <p aria-live="polite" className="flex items-center gap-1.5">
          <span className="sr-only">{`${courses.length}개 코스 중 ${activeIndex + 1}번째`}</span>
          {courses.map((course, index) => (
            <span
              aria-hidden="true"
              className={
                index === activeIndex
                  ? "size-1.5 rounded-full bg-primary"
                  : "size-1.5 rounded-full bg-border"
              }
              key={course.courseId}
            />
          ))}
        </p>
        <Button
          aria-label="다음 코스"
          className="min-w-12 px-0"
          disabled={activeIndex === courses.length - 1}
          onClick={() => scrollToIndex(activeIndex + 1)}
          variant="ghost"
        >
          <ChevronRightIcon aria-hidden="true" className="size-5" />
        </Button>
      </div>
    </div>
  );
}
