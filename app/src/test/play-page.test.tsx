import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { PlayPage } from "@/features/play/components/play-page";
import { getNextQuiz, submitQuizAnswer } from "@/lib/api/quiz";

const mockRouter = vi.hoisted(() => ({
  push: vi.fn(),
  replace: vi.fn(),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => mockRouter,
}));

vi.mock("@/lib/api/quiz", () => ({
  getNextQuiz: vi.fn(),
  submitQuizAnswer: vi.fn(),
}));

const oxQuiz = {
  quizId: 7,
  type: "OX" as const,
  difficulty: "LOW" as const,
  questionText: "프로세스는 자원을 독립적으로 가진다.",
  codeSnippet: null,
  choices: null,
  blankCount: null,
  stepOrder: 1,
  slotOrder: 1,
};

const multipleChoiceQuiz = {
  quizId: 8,
  type: "MULTIPLE_CHOICE" as const,
  difficulty: "MEDIUM" as const,
  questionText: "경쟁 상태를 막는 동기화 도구는?",
  codeSnippet: "if (locked) wait();",
  choices: [
    { choiceId: 11, content: "뮤텍스", displayOrder: 1 },
    { choiceId: 12, content: "캐시", displayOrder: 2 },
    { choiceId: 13, content: "스택", displayOrder: 3 },
    { choiceId: 14, content: "힙", displayOrder: 4 },
  ],
  blankCount: null,
  stepOrder: 1,
  slotOrder: 2,
};

const keywordBlankQuiz = {
  quizId: 9,
  type: "KEYWORD_BLANK" as const,
  difficulty: "HIGH" as const,
  questionText: "동시에 접근하면 문제가 생기는 코드 영역은?",
  codeSnippet: "enter(lock)\n  ____\nleave(lock)",
  choices: null,
  blankCount: 1,
  stepOrder: 1,
  slotOrder: 3,
};

describe("PlayPage", () => {
  beforeEach(() => {
    mockRouter.push.mockClear();
    mockRouter.replace.mockClear();
    vi.mocked(getNextQuiz).mockReset();
    vi.mocked(submitQuizAnswer).mockReset();
    window.localStorage.clear();
  });

  it("loads the next quiz from the API and submits an OX answer", async () => {
    vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true });

    render(<PlayPage />);

    expect(await screen.findByText("프로세스는 자원을 독립적으로 가진다.")).toBeInTheDocument();
    expect(screen.getByText("1/5")).toBeInTheDocument();
    expect(screen.getByText("난이도 하")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "정답 확인" })).toBeDisabled();

    fireEvent.click(screen.getByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      expect(submitQuizAnswer).toHaveBeenCalledWith(7, ["O"]);
    });
    expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=7&correct=true&streak=1");
  });

  it("renders multiple choice choices and submits the selected choice id", async () => {
    vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: false });

    render(<PlayPage />);

    expect(await screen.findByText("경쟁 상태를 막는 동기화 도구는?")).toBeInTheDocument();
    expect(screen.getByText("ts")).toBeInTheDocument();
    expect(screen.getByRole("group", { name: "사지선다 선택지" })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("radio", { name: /뮤텍스/ }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      expect(submitQuizAnswer).toHaveBeenCalledWith(8, ["11"]);
    });
    expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=8&correct=false&streak=0");
  });

  it("renders keyword blank input and submits entered answers", async () => {
    vi.mocked(getNextQuiz).mockResolvedValue(keywordBlankQuiz);
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true });

    render(<PlayPage />);

    expect(
      await screen.findByText("동시에 접근하면 문제가 생기는 코드 영역은?"),
    ).toBeInTheDocument();

    fireEvent.change(screen.getByRole("textbox", { name: "핵심 키워드 1" }), {
      target: { value: "critical section" },
    });
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      expect(submitQuizAnswer).toHaveBeenCalledWith(9, ["critical section"]);
    });
  });

  it("passes the updated consecutive correct streak to insight", async () => {
    window.localStorage.setItem("thumbsup:insight-correct-streak:api-quiz", "2");
    vi.mocked(getNextQuiz).mockResolvedValue({ ...oxQuiz, quizId: 10 });
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true });

    render(<PlayPage />);

    fireEvent.click(await screen.findByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=10&correct=true&streak=3");
    });
  });

  it("shows an error state and retries loading the quiz", async () => {
    vi.mocked(getNextQuiz)
      .mockRejectedValueOnce(new Error("network"))
      .mockResolvedValueOnce(oxQuiz);

    render(<PlayPage />);

    expect(await screen.findByText("문제를 불러오지 못했어요.")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "재시도" }));

    expect(await screen.findByText("프로세스는 자원을 독립적으로 가진다.")).toBeInTheDocument();
    expect(getNextQuiz).toHaveBeenCalledTimes(2);
  });

  it("redirects to login when the API reports an unauthorized session", async () => {
    vi.mocked(getNextQuiz).mockRejectedValue({ status: 401 });

    render(<PlayPage />);

    await waitFor(() => {
      expect(mockRouter.replace).toHaveBeenCalledWith("/login");
    });
  });
});
