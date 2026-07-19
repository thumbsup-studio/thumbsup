import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { PlayPage } from "@/features/play/components/play-page";
import { getNextQuiz, getStepQuiz, submitQuizAnswer } from "@/lib/api/quiz";

const mockRouter = vi.hoisted(() => ({
  push: vi.fn(),
  replace: vi.fn(),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => mockRouter,
}));

vi.mock("@/lib/api/quiz", () => ({
  getNextQuiz: vi.fn(),
  getStepQuiz: vi.fn(),
  submitQuizAnswer: vi.fn(),
}));

const oxQuiz = {
  quizId: 7,
  type: "OX" as const,
  difficulty: "EASY" as const,
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
  difficulty: "HARD" as const,
  questionText: "동시에 접근하면 문제가 생기는 코드 영역은?",
  codeSnippet: "enter(lock)\n  ____\nleave(lock)",
  choices: null,
  blankCount: 1,
  stepOrder: 1,
  slotOrder: 3,
};

function renderedChoiceOrder() {
  return screen.getAllByRole("radio").map((radio) => radio.closest("label")?.textContent ?? "");
}

describe("PlayPage", () => {
  beforeEach(() => {
    mockRouter.push.mockClear();
    mockRouter.replace.mockClear();
    vi.mocked(getNextQuiz).mockReset();
    vi.mocked(getStepQuiz).mockReset();
    vi.mocked(submitQuizAnswer).mockReset();
    window.localStorage.clear();
  });

  it("loads the next quiz from the API and submits an OX answer", async () => {
    vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

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
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: false, retryHint: null });

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

  it("renders keyword blank input and submits trimmed answers", async () => {
    vi.mocked(getNextQuiz).mockResolvedValue(keywordBlankQuiz);
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

    render(<PlayPage />);

    expect(
      await screen.findByText("동시에 접근하면 문제가 생기는 코드 영역은?"),
    ).toBeInTheDocument();

    fireEvent.change(screen.getByRole("textbox", { name: "핵심 키워드 1" }), {
      target: { value: "  critical section  " },
    });
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      expect(submitQuizAnswer).toHaveBeenCalledWith(9, ["critical section"]);
    });
  });

  it("passes the updated consecutive correct streak to insight", async () => {
    window.localStorage.setItem("thumbsup:insight-correct-streak:api-quiz:1", "2");
    vi.mocked(getNextQuiz).mockResolvedValue({ ...oxQuiz, quizId: 10, slotOrder: 3 });
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

    render(<PlayPage />);

    fireEvent.click(await screen.findByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=10&correct=true&streak=3");
    });
  });

  it("passes review correct count and review streak to insight without touching daily streak", async () => {
    window.localStorage.setItem("thumbsup:insight-correct-streak:api-quiz:1", "4");
    vi.mocked(getStepQuiz).mockResolvedValue({ ...oxQuiz, quizId: 12, slotOrder: 3 });
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

    render(<PlayPage review={{ step: 2, slot: 3, correct: 2, streak: 2, topic: "문맥 전환" }} />);

    fireEvent.click(await screen.findByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith(
        "/insight?step=2&slot=3&rc=3&rs=3&topic=%EB%AC%B8%EB%A7%A5+%EC%A0%84%ED%99%98&quizId=12&correct=true",
      );
    });
    expect(window.localStorage.getItem("thumbsup:insight-correct-streak:api-quiz:1")).toBe("4");
  });

  it("keeps the server choice order when playing a step for the first time", async () => {
    vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);

    render(<PlayPage />);

    await screen.findByRole("group", { name: "사지선다 선택지" });

    expect(renderedChoiceOrder()).toEqual(["A뮤텍스", "B캐시", "C스택", "D힙"]);
  });

  it("shuffles the choice order when re-solving a step in review mode", async () => {
    const random = vi.spyOn(Math, "random").mockReturnValue(0);
    vi.mocked(getStepQuiz).mockResolvedValue(multipleChoiceQuiz);
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

    render(<PlayPage review={{ step: 2, slot: 2, correct: 0, streak: 0, topic: "동기화" }} />);

    await screen.findByRole("group", { name: "사지선다 선택지" });

    expect(renderedChoiceOrder()).toEqual(["A캐시", "B스택", "C힙", "D뮤텍스"]);

    // 표시 순서가 바뀌어도 채점은 choiceId로 이뤄지므로 제출값은 그대로여야 한다.
    fireEvent.click(screen.getByRole("radio", { name: /뮤텍스/ }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      expect(submitQuizAnswer).toHaveBeenCalledWith(8, ["11"]);
    });

    random.mockRestore();
  });

  it("keeps the shuffled order stable while the user changes the selection", async () => {
    const random = vi.spyOn(Math, "random").mockReturnValue(0);
    vi.mocked(getStepQuiz).mockResolvedValue(multipleChoiceQuiz);

    render(<PlayPage review={{ step: 2, slot: 2, correct: 0, streak: 0, topic: "동기화" }} />);

    await screen.findByRole("group", { name: "사지선다 선택지" });
    random.mockReturnValue(0.99);

    fireEvent.click(screen.getByRole("radio", { name: /스택/ }));
    fireEvent.click(screen.getByRole("radio", { name: /힙/ }));

    expect(renderedChoiceOrder()).toEqual(["A캐시", "B스택", "C힙", "D뮤텍스"]);

    random.mockRestore();
  });

  it("resets the consecutive correct streak when a step starts from slot one", async () => {
    window.localStorage.setItem("thumbsup:insight-correct-streak:api-quiz:1", "4");
    vi.mocked(getNextQuiz).mockResolvedValue({ ...oxQuiz, quizId: 11, slotOrder: 1 });
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

    render(<PlayPage />);

    fireEvent.click(await screen.findByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=11&correct=true&streak=1");
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

  describe("중·상 난이도 오답 재도전", () => {
    const mcEliminate13 = {
      isCorrect: false,
      retryHint: { eliminatedChoiceId: 13, blankHints: null },
    };

    it("중 난이도 오답이면 해설로 넘어가지 않고 재도전 화면으로 들어가며 이전 선택을 초기화한다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
      vi.mocked(submitQuizAnswer).mockResolvedValue(mcEliminate13);

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: /뮤텍스/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      // 사지선다는 힌트가 아니라 오답 소거이므로, 문구가 그 사실을 정확히 말해야 한다.
      expect(await screen.findByText(/틀린 선택지 하나를 지웠어요/)).toBeInTheDocument();
      expect(mockRouter.push).not.toHaveBeenCalled();
      // 이전 선택 초기화 → 제출 버튼이 다시 비활성
      expect(screen.getByRole("radio", { name: /뮤텍스/ })).not.toBeChecked();
      expect(screen.getByRole("button", { name: "정답 확인" })).toBeDisabled();
    });

    it("하 난이도 오답이면 재도전 없이 곧바로 해설로 이동한다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
      vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: false, retryHint: null });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: "X" }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await waitFor(() => {
        expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=7&correct=false&streak=0");
      });
    });

    it("재도전에서 정답이면 연속 정답을 유지한 채(+1) 해설로 이동한다", async () => {
      window.localStorage.setItem("thumbsup:insight-correct-streak:api-quiz:1", "2");
      vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
      vi.mocked(submitQuizAnswer)
        .mockResolvedValueOnce(mcEliminate13)
        .mockResolvedValueOnce({ isCorrect: true, retryHint: null });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: /뮤텍스/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));
      await screen.findByText(/오답이에요/);

      fireEvent.click(screen.getByRole("radio", { name: /캐시/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await waitFor(() => {
        expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=8&correct=true&streak=3");
      });
    });

    it("재도전에서도 오답이면 연속 정답을 0으로 만들고 해설로 이동한다", async () => {
      window.localStorage.setItem("thumbsup:insight-correct-streak:api-quiz:1", "2");
      vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
      vi.mocked(submitQuizAnswer)
        .mockResolvedValueOnce(mcEliminate13)
        // 서버는 두 번째 오답에도 힌트를 주지만, 앱은 재도전을 이미 써서 무시하고 해설로 넘어가야 한다.
        .mockResolvedValueOnce({
          isCorrect: false,
          retryHint: { eliminatedChoiceId: 14, blankHints: null },
        });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: /뮤텍스/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));
      await screen.findByText(/오답이에요/);

      fireEvent.click(screen.getByRole("radio", { name: /캐시/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await waitFor(() => {
        expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=8&correct=false&streak=0");
      });
    });

    it("재도전 화면에서 소거된 선택지는 비활성이고, 첫 시도에 고른 오답은 여전히 고를 수 있다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
      vi.mocked(submitQuizAnswer).mockResolvedValue(mcEliminate13); // 스택(13) 소거

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: /뮤텍스/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));
      await screen.findByText(/오답이에요/);

      expect(screen.getByRole("radio", { name: /스택/ })).toBeDisabled();
      expect(screen.getByRole("radio", { name: /뮤텍스/ })).toBeEnabled();
    });

    it("재도전 제출이 실패하면 에러를 보여주고 재도전 화면을 유지한다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
      vi.mocked(submitQuizAnswer)
        .mockResolvedValueOnce(mcEliminate13)
        .mockRejectedValueOnce(new Error("network"));

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: /뮤텍스/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));
      await screen.findByText(/오답이에요/);

      fireEvent.click(screen.getByRole("radio", { name: /캐시/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      expect(await screen.findByText("정답을 확인하지 못했어요.")).toBeInTheDocument();
      expect(screen.getByText(/오답이에요/)).toBeInTheDocument();
      expect(mockRouter.push).not.toHaveBeenCalled();
    });

    it("힌트가 없는 오답 응답이면 재도전 없이 해설로 이동한다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
      vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: false, retryHint: null });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: /뮤텍스/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await waitFor(() => {
        expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=8&correct=false&streak=0");
      });
    });

    it("빈칸 오답이면 슬롯별 첫 글자·글자수 힌트를 보여준다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue({ ...keywordBlankQuiz, blankCount: 2 });
      vi.mocked(submitQuizAnswer).mockResolvedValue({
        isCorrect: false,
        retryHint: {
          eliminatedChoiceId: null,
          blankHints: [
            { slotOrder: 1, revealedPrefix: "시", answerLength: 4 },
            { slotOrder: 2, revealedPrefix: "데", answerLength: 3 },
          ],
        },
      });

      render(<PlayPage />);

      fireEvent.change(await screen.findByRole("textbox", { name: "핵심 키워드 1" }), {
        target: { value: "오답" },
      });
      fireEvent.change(screen.getByRole("textbox", { name: "핵심 키워드 2" }), {
        target: { value: "오답" },
      });
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      // 빈칸은 실제로 첫 글자 힌트를 주므로 문구도 그렇게 안내한다.
      expect(await screen.findByText(/첫 글자만 살짝 알려줄게요/)).toBeInTheDocument();
      expect(screen.getByText(/시 ○ ○ ○ \(4글자\)/)).toBeInTheDocument();
      expect(screen.getByText(/데 ○ ○ \(3글자\)/)).toBeInTheDocument();
      expect(mockRouter.push).not.toHaveBeenCalled();
    });
  });
});
