"use client";

import { useEffect, useRef, useState } from "react";
import { TodayCourseCard } from "@/features/home/components/today-course-card";
import type { HomeCourse } from "@/features/home/types";

type CourseCarouselProps = {
  courses: HomeCourse[];
  completed: boolean;
};

/**
 * 학습 중인 코스 캐러셀(#23) — 서버가 최근 푼 순으로 준 목록을 좌우 스크롤 스냅으로 넘겨 본다.
 * 코스가 1개면 스냅 컨테이너·인디케이터 없이 단일 카드로 렌더한다(TC-23-06).
 * 현재 위치는 IntersectionObserver로 추적해 점 인디케이터와 스크린리더 문구를 갱신한다.
 */
export function CourseCarousel({ courses, completed }: CourseCarouselProps) {
  const listRef = useRef<HTMLUListElement>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const multiple = courses.length > 1;

  useEffect(() => {
    if (!multiple) {
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
  }, [multiple]);

  const first = courses[0];
  if (!first) {
    return null; // 서버가 최소 1개를 보장하지만(이슈 240), 타입 좁히기용 방어
  }

  if (!multiple) {
    return <TodayCourseCard course={first} completed={completed} />;
  }

  return (
    <section aria-label="학습 중인 코스">
      <ul className="flex snap-x snap-mandatory gap-3 overflow-x-auto" ref={listRef}>
        {courses.map((course) => (
          <li className="w-full shrink-0 snap-center" key={course.courseId}>
            <TodayCourseCard course={course} completed={completed} />
          </li>
        ))}
      </ul>
      <p className="mt-3 flex items-center justify-center gap-1.5">
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
    </section>
  );
}
