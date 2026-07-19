import { render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { CoursesIndexScreen } from "@/features/authoring/components/courses-index-screen";
import type { AuthoringCourse } from "@/features/authoring/types";
import { ApiError } from "@/lib/api";

const { getAuthoringCoursesMock, mockRouter } = vi.hoisted(() => ({
  getAuthoringCoursesMock: vi.fn(),
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/api", () => ({ getAuthoringCourses: getAuthoringCoursesMock }));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));

const COURSES: AuthoringCourse[] = [{ courseId: 1, title: "운영체제", category: "CS" }];

beforeEach(() => {
  getAuthoringCoursesMock.mockReset();
  mockRouter.replace.mockReset();
});

describe("CoursesIndexScreen", () => {
  it("코스 카드를 렌더하고 상세 경로로 링크한다", async () => {
    getAuthoringCoursesMock.mockResolvedValue(COURSES);

    render(<CoursesIndexScreen />);

    const link = await screen.findByRole("link", { name: /운영체제/ });
    expect(link).toHaveAttribute("href", "/authoring/quizzes/1");
  });

  it("코스가 없으면 빈 상태를 보여준다", async () => {
    getAuthoringCoursesMock.mockResolvedValue([]);

    render(<CoursesIndexScreen />);

    expect(await screen.findByText("등록된 코스가 없어요")).toBeInTheDocument();
  });

  it("세션 만료(401)면 로그인으로 이동한다", async () => {
    getAuthoringCoursesMock.mockRejectedValue(
      new ApiError({ code: "UNAUTHORIZED", status: 401, message: "unauthorized" }),
    );

    render(<CoursesIndexScreen />);

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/login"));
  });

  it("권한 없음(403)이면 홈으로 이동한다", async () => {
    getAuthoringCoursesMock.mockRejectedValue(
      new ApiError({ code: "FORBIDDEN", status: 403, message: "forbidden" }),
    );

    render(<CoursesIndexScreen />);

    await waitFor(() => expect(mockRouter.replace).toHaveBeenCalledWith("/"));
  });
});
