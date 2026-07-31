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
            hint: "하드웨어 자원 관리에 필요한 권한 수준을 생각해 보세요.",
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

// 라이브 퀴즈는 서버 QuizToGeneratedQuizMapper가 choices/answerKeywords/keywords/derivedConcepts/
// followUpQuestions를 null이 아닌 빈 배열([])로 채워 보낸다(이슈 182 회귀 픽스). 빈 배열은 진리값이
// true라 `x ? ... : null` 가드로는 걸러지지 않고 내용 없는 섹션 제목만 남는 버그가 있었다.
const DETAIL_EMPTY_ARRAYS: AuthoringCourseDetail = {
  courseId: 2,
  title: "네트워크",
  steps: [
    {
      stepOrder: 1,
      topic: "TCP 기초",
      quizzes: [
        {
          quizId: 201,
          slotOrder: 1,
          generated: {
            type: "MULTIPLE_CHOICE",
            difficulty: "EASY",
            questionText: "TCP는 연결 지향 프로토콜이다.",
            hint: "연결 수립 전에 양쪽이 상태를 교환하는지 살펴보세요.",
            codeSnippet: null,
            explanationSummary: "TCP는 3-way handshake로 연결을 수립한다.",
            explanationExample: null,
            wrongAnswerExplanation: "UDP와 혼동 금지.",
            correctAnswer: null,
            choices: [],
            answerKeywords: [],
            followUpQuestions: [],
            derivedConcepts: [],
            keywords: [],
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
    expect(
      screen.getByText("하드웨어 자원 관리에 필요한 권한 수준을 생각해 보세요."),
    ).toBeInTheDocument(); // 제출 전 힌트 검수
    expect(screen.getByText(/꼬리질문 1개/)).toBeInTheDocument(); // 꼬리질문 disclosure
    expect(screen.getByText("정답: O")).toBeInTheDocument();
  });

  it("서버가 채워 보낸 빈 배열 필드는 내용 없는 섹션 제목을 렌더하지 않는다", async () => {
    getCourseQuizzesMock.mockResolvedValue(DETAIL_EMPTY_ARRAYS);

    renderScreen();
    fireEvent.click(await screen.findByRole("button", { name: /STEP 1/ }));
    fireEvent.click(await screen.findByRole("button", { name: /TCP는 연결 지향 프로토콜이다\./ }));

    expect(await screen.findByText("TCP는 3-way handshake로 연결을 수립한다.")).toBeInTheDocument();
    expect(screen.queryByText("정답(빈칸별 동의어)")).not.toBeInTheDocument();
    expect(screen.queryByText("키워드")).not.toBeInTheDocument();
    expect(screen.queryByText("파생 개념")).not.toBeInTheDocument();
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
