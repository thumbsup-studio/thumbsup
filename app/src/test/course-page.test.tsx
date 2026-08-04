import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { CoursePage } from "@/features/course/components/course-page";
import { type CourseItem, getCourses } from "@/lib/api/course";

const mockRouter = vi.hoisted(() => ({
  push: vi.fn(),
  replace: vi.fn(),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => mockRouter,
}));

vi.mock("@/lib/api/course", () => ({
  getCourses: vi.fn(),
}));

const courseWithMixedSteps: CourseItem = {
  courseId: 1,
  title: "운영체제",
  category: "CS",
  steps: [
    { stepOrder: 1, topic: "프로세스와 스레드", estimatedMinutes: 10, state: "COMPLETED" },
    { stepOrder: 2, topic: "동기화", estimatedMinutes: 12, state: "SOLVABLE" },
    { stepOrder: 3, topic: "교착 상태", estimatedMinutes: 15, state: "LOCKED" },
  ],
};

const courseAllLocked: CourseItem = {
  courseId: 2,
  title: "네트워크",
  category: "CS",
  steps: [{ stepOrder: 1, topic: "OSI 7계층", estimatedMinutes: 8, state: "LOCKED" }],
};

const courseCompleted: CourseItem = {
  courseId: 3,
  title: "자료구조",
  category: "CS",
  steps: [
    { stepOrder: 1, topic: "배열", estimatedMinutes: 5, state: "COMPLETED" },
    { stepOrder: 2, topic: "연결 리스트", estimatedMinutes: 5, state: "COMPLETED" },
  ],
};

describe("CoursePage", () => {
  beforeEach(() => {
    vi.mocked(getCourses).mockReset();
    mockRouter.push.mockReset();
    mockRouter.replace.mockReset();
  });

  it("코스 목록과 스텝을 상태와 함께 불러와 보여준다", async () => {
    vi.mocked(getCourses).mockResolvedValue({ items: [courseWithMixedSteps] });

    render(<CoursePage />);

    expect(await screen.findByText("운영체제")).toBeInTheDocument();
    expect(screen.getByText("프로세스와 스레드")).toBeInTheDocument();
    expect(screen.getByText("동기화")).toBeInTheDocument();
    expect(screen.getByText("교착 상태")).toBeInTheDocument();
    expect(screen.getByText("완료")).toBeInTheDocument();
    expect(screen.getByText("풀기")).toBeInTheDocument();
    expect(screen.getByText("잠김")).toBeInTheDocument();
  });

  it("완료 스텝은 복습 링크로, 풀 수 있는 스텝은 해당 코스의 다음 문제로 진입한다", async () => {
    vi.mocked(getCourses).mockResolvedValue({ items: [courseWithMixedSteps] });

    render(<CoursePage />);

    const completedLink = await screen.findByRole("link", { name: /프로세스와 스레드/ });
    expect(completedLink).toHaveAttribute(
      "href",
      "/play?step=1&slot=1&rc=0&rs=0&topic=%ED%94%84%EB%A1%9C%EC%84%B8%EC%8A%A4%EC%99%80+%EC%8A%A4%EB%A0%88%EB%93%9C",
    );

    const solvableLink = screen.getByRole("link", { name: /동기화/ });
    expect(solvableLink).toHaveAttribute("href", "/play?courseId=1");
  });

  it("잠긴 스텝은 링크가 없고 클릭할 수 없다", async () => {
    vi.mocked(getCourses).mockResolvedValue({ items: [courseWithMixedSteps] });

    render(<CoursePage />);

    await screen.findByText("교착 상태");

    expect(screen.queryByRole("link", { name: /교착 상태/ })).not.toBeInTheDocument();
  });

  it("코스가 없으면 빈 상태를 보여준다", async () => {
    vi.mocked(getCourses).mockResolvedValue({ items: [] });

    render(<CoursePage />);

    expect(await screen.findByText("등록된 코스가 없어요")).toBeInTheDocument();
  });

  it("목록을 불러오지 못하면 에러를 보여준다", async () => {
    vi.mocked(getCourses).mockRejectedValue(new Error("network"));

    render(<CoursePage />);

    const status = await screen.findByRole("status");
    expect(status).toHaveTextContent("코스 목록을 불러오지 못했어요.");
  });

  it("인증이 만료되면 로그인 화면으로 보낸다", async () => {
    vi.mocked(getCourses).mockRejectedValue({ status: 401 });

    render(<CoursePage />);

    await waitFor(() => {
      expect(mockRouter.replace).toHaveBeenCalledWith("/login");
    });
  });

  it("풀 수 있는 스텝이 있는 첫 코스만 기본으로 펼치고 나머지는 접는다", async () => {
    vi.mocked(getCourses).mockResolvedValue({ items: [courseAllLocked, courseWithMixedSteps] });

    render(<CoursePage />);

    await screen.findByText("네트워크");

    expect(screen.queryByText("OSI 7계층")).not.toBeInTheDocument();
    expect(screen.getByText("동기화")).toBeInTheDocument();
  });

  it("코스 헤더를 누르면 스텝 목록이 펼쳐지고 다시 누르면 접힌다", async () => {
    vi.mocked(getCourses).mockResolvedValue({ items: [courseAllLocked] });

    render(<CoursePage />);

    const toggle = await screen.findByRole("button", { name: /네트워크/ });
    expect(toggle).toHaveAttribute("aria-expanded", "false");
    expect(screen.queryByText("OSI 7계층")).not.toBeInTheDocument();

    fireEvent.click(toggle);
    expect(toggle).toHaveAttribute("aria-expanded", "true");
    expect(screen.getByText("OSI 7계층")).toBeInTheDocument();

    fireEvent.click(toggle);
    expect(toggle).toHaveAttribute("aria-expanded", "false");
    expect(screen.queryByText("OSI 7계층")).not.toBeInTheDocument();
  });

  it("스텝을 모두 완료한 코스에는 완주 배지가 보인다", async () => {
    vi.mocked(getCourses).mockResolvedValue({ items: [courseWithMixedSteps, courseCompleted] });

    render(<CoursePage />);

    await screen.findByText("자료구조");

    expect(screen.getByText("완주")).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /운영체제/ })?.textContent,
    ).not.toContain("완주");
  });
});
