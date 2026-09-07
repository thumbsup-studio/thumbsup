"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { getAuthoringCourses } from "@/features/authoring/api";
import type { AuthoringCourse } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "success"; courses: AuthoringCourse[] };

/** 코스 인덱스 — 라이브 문제를 코스 단위로 진입하는 목록. 코스 클릭 시 상세로 이동. */
export function CoursesIndexScreen() {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ status: "loading" });

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const courses = await getAuthoringCourses();
      setState({ status: "success", courses });
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      if (error instanceof ApiError && error.status === 403) {
        router.replace("/");
        return;
      }
      setState({ status: "error" });
    }
  }, [router]);

  useEffect(() => {
    void load();
  }, [load]);

  if (state.status === "loading") {
    return <CoursesSkeleton />;
  }
  if (state.status === "error") {
    return (
      <Feedback onRetry={() => void load()} tone="error">
        코스를 불러오지 못했어요.
      </Feedback>
    );
  }
  if (state.courses.length === 0) {
    return <EmptyState description="아직 등록된 코스가 없어요." title="등록된 코스가 없어요" />;
  }

  return (
    <ul className="flex flex-col gap-3">
      {state.courses.map((course) => (
        <li key={course.courseId}>
          <Link className="block" href={`/authoring/quizzes/${course.courseId}`}>
            <Card className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <span className="text-base font-bold text-ink">{course.title}</span>
                <Chip tone="neutral">{course.category}</Chip>
              </div>
              <span aria-hidden className="text-ink-muted">
                →
              </span>
            </Card>
          </Link>
        </li>
      ))}
    </ul>
  );
}

function CoursesSkeleton() {
  return (
    <div className="flex flex-col gap-3">
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-16 w-full" key={row} />
      ))}
    </div>
  );
}
