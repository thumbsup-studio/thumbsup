import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { CourseQuizzesScreen } from "@/features/authoring/components/course-quizzes-screen";
import type { AuthoringCourseDetail } from "@/features/authoring/types";
import { AppToastProvider } from "@/providers/app-toast-provider";

const { getCourseQuizzesMock, improveQuizMock, mockRouter } = vi.hoisted(() => ({
  getCourseQuizzesMock: vi.fn(),
  improveQuizMock: vi.fn(),
  mockRouter: { push: vi.fn(), replace: vi.fn() },
}));

vi.mock("@/features/authoring/api", () => ({
  getAuthoringCourseQuizzes: getCourseQuizzesMock,
  improveQuiz: improveQuizMock,
}));
vi.mock("next/navigation", () => ({ useRouter: () => mockRouter }));

const DETAIL: AuthoringCourseDetail = {
  courseId: 1,
  title: "운영체제",
  steps: [
    {
      stepOrder: 1,
      topic: "OS 개요",
      quizzes: [
        {
          quizId: 101,
          slotOrder: 1,
          generated: {
            type: "OX",
            difficulty: "EASY",
            questionText: "커널은 특권 수준에서 실행된다.",
            codeSnippet: null,
            explanationSummary: "커널은 하드웨어 자원을 관리한다.",
            explanationExample: null,
            wrongAnswerExplanation: "사용자 모드와 혼동 금지.",
            correctAnswer: "O",
            choices: null,
            answerKeywords: null,
            followUpQuestions: [
              {
                content: "시스템 콜이란?",
                isPrimary: true,
                difficulty: "MEDIUM",
                oneLineAnswer: "OS 기능 요청 인터페이스",
                blocks: [{ label: "정의", content: "응용이 커널 기능을 부르는 통로" }],
                keywords: [{ keyword: "트랩", description: "소프트웨어 인터럽트" }],
              },
            ],
            derivedConcepts: null,
            keywords: [{ keyword: "커널", description: "OS의 핵심" }],
          },
        },
      ],
    },
  ],
};

function renderScreen() {
  render(
    <AppToastProvider>
      <CourseQuizzesScreen courseId={1} />
    </AppToastProvider>,
  );
}

beforeEach(() => {
  getCourseQuizzesMock.mockReset();
  improveQuizMock.mockReset();
  mockRouter.push.mockReset();
});

describe("CourseQuizzesScreen", () => {
  it("초기에는 스텝이 접혀 있어 문제 텍스트가 보이지 않는다", async () => {
    getCourseQuizzesMock.mockResolvedValue(DETAIL);

    renderScreen();

    expect(await screen.findByText(/STEP 1 · OS 개요/)).toBeInTheDocument();
    expect(screen.queryByText("커널은 특권 수준에서 실행된다.")).not.toBeInTheDocument();
  });

  it("스텝 클릭 → 문제 행, 문제 클릭 → 키워드·해설·꼬리질문 전체 상세가 보인다", async () => {
    getCourseQuizzesMock.mockResolvedValue(DETAIL);

    renderScreen();
    fireEvent.click(await screen.findByRole("button", { name: /STEP 1/ }));

    const quizRow = await screen.findByRole("button", { name: /커널은 특권 수준에서 실행된다\./ });
    fireEvent.click(quizRow);

    expect(await screen.findByText("커널")).toBeInTheDocument(); // 키워드 사전
    expect(screen.getByText("커널은 하드웨어 자원을 관리한다.")).toBeInTheDocument(); // 해설 요약
    expect(screen.getByText(/꼬리질문 1개/)).toBeInTheDocument(); // 꼬리질문 disclosure
    expect(screen.getByText("정답: O")).toBeInTheDocument();
  });

  it("문제 상세의 개선 버튼으로 개선 시트를 연다", async () => {
    getCourseQuizzesMock.mockResolvedValue(DETAIL);

    renderScreen();
    fireEvent.click(await screen.findByRole("button", { name: /STEP 1/ }));
    fireEvent.click(await screen.findByRole("button", { name: /커널은 특권 수준/ }));
    fireEvent.click(screen.getByRole("button", { name: "개선" }));

    expect(await screen.findByLabelText("개선 지시")).toBeInTheDocument();
  });
});
