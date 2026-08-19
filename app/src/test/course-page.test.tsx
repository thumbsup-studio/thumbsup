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

/** stepOrder는 코스 무관 전역 순번이라 두 번째 이후 코스는 1보다 큰 값에서 시작한다(이슈 290). */
const secondCourseWithGlobalStepOffset: CourseItem = {
  courseId: 2,
  title: "디자인 패턴",
  category: "CS",
  steps: [
    { stepOrder: 13, topic: "생성 패턴 개요와 싱글턴", estimatedMinutes: 10, state: "SOLVABLE" },
    { stepOrder: 14, topic: "팩토리 메서드", estimatedMinutes: 10, state: "LOCKED" },
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
      "/play?step=1&slot=1&rc=0&rs=0&topic=%ED%94%84%EB%A1%9C%EC%84%B8%EC%8A%A4%EC%99%80+%EC%8A%A4%EB%A0%88%EB%93%9C&rsm=1",
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
    expect(screen.queryByRole("button", { name: /운영체제/ })?.textContent).not.toContain("완주");
  });

  it("홈의 복습하기로 지정된 코스가 있으면 기본 규칙 대신 그 코스를 펼친다", async () => {
    vi.mocked(getCourses).mockResolvedValue({ items: [courseWithMixedSteps, courseCompleted] });

    render(<CoursePage initialOpenCourseId={courseCompleted.courseId} />);

    await screen.findByText("배열");

    expect(screen.queryByText("동기화")).not.toBeInTheDocument();
  });

  it("지정된 코스 id가 목록에 없으면 기본 규칙(풀 수 있는 스텝이 있는 첫 코스)으로 펼친다", async () => {
    vi.mocked(getCourses).mockResolvedValue({ items: [courseWithMixedSteps, courseCompleted] });

    render(<CoursePage initialOpenCourseId={999} />);

    await screen.findByText("동기화");

    expect(screen.queryByText("배열")).not.toBeInTheDocument();
  });

  it("전역 stepOrder가 아니라 코스 안 순번으로 STEP 번호를 표시한다", async () => {
    vi.mocked(getCourses).mockResolvedValue({ items: [secondCourseWithGlobalStepOffset] });

    render(<CoursePage />);

    await screen.findByText("생성 패턴 개요와 싱글턴");

    expect(screen.getByText(/STEP 1 ·/)).toBeInTheDocument();
    expect(screen.getByText(/STEP 2 ·/)).toBeInTheDocument();
    expect(screen.queryByText(/STEP 13/)).not.toBeInTheDocument();
    expect(screen.queryByText(/STEP 14/)).not.toBeInTheDocument();
  });
});
