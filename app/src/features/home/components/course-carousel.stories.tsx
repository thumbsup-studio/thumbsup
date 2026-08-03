import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import type { HomeCourse } from "@/features/home/types";
import { CourseCarousel } from "./course-carousel";

/**
 * 학습 중인 코스 캐러셀(#23) — 서버가 최근 푼 순으로 준 코스 목록을 좌우 스크롤 스냅으로 넘긴다.
 * 코스가 1개면 인디케이터 없이 단일 카드로 렌더된다(TC-23-06).
 */
const osCourse: HomeCourse = {
  courseId: 1,
  title: "운영체제",
  subtitle: "프로세스와 스레드",
  progress: 3,
  total: 8,
  durationLabel: "3분이면 끝나요",
};

const designPatternCourse: HomeCourse = {
  courseId: 2,
  title: "디자인 패턴",
  subtitle: "팩토리 메서드와 추상 팩토리",
  progress: 1,
  total: 2,
  durationLabel: "3분이면 끝나요",
};

const networkCourse: HomeCourse = {
  courseId: 3,
  title: "네트워크",
  subtitle: "TCP 3-way handshake",
  progress: 0,
  total: 10,
  durationLabel: "5분이면 끝나요",
};

const meta: Meta<typeof CourseCarousel> = {
  title: "Home/CourseCarousel",
  component: CourseCarousel,
  args: { courses: [designPatternCourse, osCourse, networkCourse], completed: false },
  decorators: [
    (Story) => (
      <div className="mx-auto w-full max-w-md">
        <Story />
      </div>
    ),
  ],
};
export default meta;

export const Playground: StoryObj<typeof CourseCarousel> = {};

export const SingleCourse: StoryObj<typeof CourseCarousel> = {
  args: { courses: [osCourse] },
};

export const TodayCompleted: StoryObj<typeof CourseCarousel> = {
  args: { completed: true },
};
