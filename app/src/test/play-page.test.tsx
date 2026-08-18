import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { PlayPage } from "@/features/play/components/play-page";
import { getNextQuiz, getStepQuiz, requestQuizHint, submitQuizAnswer } from "@/lib/api/quiz";

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
  requestQuizHint: vi.fn(),
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
  totalCount: 5,
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
  totalCount: 5,
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
  totalCount: 5,
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
    vi.mocked(requestQuizHint).mockReset();
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

  it("스텝의 문제 수가 5가 아니어도 서버가 준 totalCount로 표시한다", async () => {
    // 스텝마다 문제 수가 달라, 5로 고정하면 3문제짜리 스텝은 완주에 닿지 못한다(이슈 266).
    vi.mocked(getNextQuiz).mockResolvedValue({ ...oxQuiz, totalCount: 3 });

    render(<PlayPage />);

    expect(await screen.findByText("1/3")).toBeInTheDocument();
    expect(screen.getByLabelText("문제 진행률")).toHaveAttribute("aria-valuemax", "3");
  });

  it("마지막 문제를 풀면 완주로 처리한다 — 총 문제 수가 3이어도", async () => {
    vi.mocked(getNextQuiz).mockResolvedValue({ ...oxQuiz, slotOrder: 3, totalCount: 3 });
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

    render(<PlayPage />);

    fireEvent.click(await screen.findByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      // done=1이 완주 표시 — totalCount가 5로 고정돼 있으면 3번째 문제로는 여기 닿지 못한다.
      expect(mockRouter.push).toHaveBeenCalledWith(expect.stringContaining("done=1"));
    });
  });

  it("연속 정답이 2 이상이면 콤보를 화면에 띄운다", async () => {
    window.localStorage.setItem(
      "thumbsup:play-session:1",
      JSON.stringify({ answered: 2, correct: 2, combo: 2, bestCombo: 2 }),
    );
    vi.mocked(getNextQuiz).mockResolvedValue({ ...oxQuiz, slotOrder: 3 });

    render(<PlayPage />);

    expect(await screen.findByText("2연속")).toBeInTheDocument();
  });

  it("연속 정답이 1이면 콤보를 띄우지 않는다", async () => {
    window.localStorage.setItem(
      "thumbsup:play-session:1",
      JSON.stringify({ answered: 1, correct: 1, combo: 1, bestCombo: 1 }),
    );
    vi.mocked(getNextQuiz).mockResolvedValue({ ...oxQuiz, slotOrder: 2 });

    render(<PlayPage />);

    await screen.findByText("프로세스는 자원을 독립적으로 가진다.");
    expect(screen.queryByText("1연속")).not.toBeInTheDocument();
  });

  it("코스 탭에서 진입하면 courseId로 다음 문제를 요청하고 해설 화면까지 courseId를 이어 싣는다", async () => {
    vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
    vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

    render(<PlayPage courseId={2} />);

    fireEvent.click(await screen.findByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    expect(getNextQuiz).toHaveBeenCalledWith(2);
    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith(
        "/insight?quizId=7&correct=true&streak=1&courseId=2",
      );
    });
  });

  it("코스 탭 진입 시 뒤로가기 버튼이 코스 목록으로 이어진다", async () => {
    vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);

    render(<PlayPage courseId={2} />);

    expect(await screen.findByRole("link", { name: "코스 목록으로 돌아가기" })).toHaveAttribute(
      "href",
      "/course",
    );
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

    render(
      <PlayPage
        review={{ step: 2, slot: 3, correct: 2, streak: 2, topic: "문맥 전환", single: false, resumeSlot: 3 }}
      />,
    );

    fireEvent.click(await screen.findByRole("radio", { name: "O" }));
    fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith(
        "/insight?step=2&slot=3&rc=3&rs=3&topic=%EB%AC%B8%EB%A7%A5+%EC%A0%84%ED%99%98&rsm=3&quizId=12&correct=true",
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

    render(
      <PlayPage
        review={{ step: 2, slot: 2, correct: 0, streak: 0, topic: "동기화", single: false, resumeSlot: 2 }}
      />,
    );

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

    render(
      <PlayPage
        review={{ step: 2, slot: 2, correct: 0, streak: 0, topic: "동기화", single: false, resumeSlot: 2 }}
      />,
    );

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

  describe("제출 전 사용자 요청 힌트", () => {
    it.each([
      ["OX", oxQuiz],
      ["사지선다", multipleChoiceQuiz],
      ["키워드 빈칸", keywordBlankQuiz],
    ])("%s 문제에 동일한 힌트 진입점을 보여준다", async (_label, targetQuiz) => {
      vi.mocked(getNextQuiz).mockResolvedValue(targetQuiz);

      render(<PlayPage />);

      await screen.findByText(targetQuiz.questionText);
      expect(screen.getByRole("button", { name: "힌트 보기" })).toBeEnabled();
    });

    it("한 문장 힌트를 표시하되 선택 답안과 채점·스트릭에는 영향을 주지 않는다", async () => {
      const hint = "프로세스가 자원을 소유하는 단위를 떠올려 보세요.";
      vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
      vi.mocked(requestQuizHint).mockResolvedValue({ hint });
      vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

      render(<PlayPage />);

      const answer = await screen.findByRole("radio", { name: "O" });
      fireEvent.click(answer);
      fireEvent.click(screen.getByRole("button", { name: "힌트 보기" }));

      expect(await screen.findByText(hint)).toBeInTheDocument();
      expect(requestQuizHint).toHaveBeenCalledWith(7);
      expect(answer).toBeChecked();
      expect(submitQuizAnswer).not.toHaveBeenCalled();
      expect(screen.getByRole("button", { name: "힌트 확인함" })).toBeDisabled();

      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await waitFor(() => {
        expect(submitQuizAnswer).toHaveBeenCalledWith(7, ["O"]);
      });
      expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=7&correct=true&streak=1");
    });

    it("힌트를 불러오는 동안에도 답안은 바꿀 수 있고 제출과 중복 요청만 잠근다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
      vi.mocked(requestQuizHint).mockReturnValue(new Promise(() => {}));

      render(<PlayPage />);

      const answer = await screen.findByRole("radio", { name: "O" });
      fireEvent.click(answer);
      fireEvent.click(screen.getByRole("button", { name: "힌트 보기" }));

      expect(screen.getByRole("button", { name: "힌트 불러오는 중" })).toBeDisabled();
      expect(answer).toBeEnabled();
      fireEvent.click(screen.getByRole("radio", { name: "X" }));
      expect(screen.getByRole("radio", { name: "X" })).toBeChecked();
      expect(screen.getByRole("button", { name: "정답 확인" })).toBeDisabled();
      expect(requestQuizHint).toHaveBeenCalledTimes(1);
    });

    it("이전 문제의 늦은 힌트 응답을 새 문제에 표시하지 않는다", async () => {
      let resolveOldHint: ((value: { hint: string }) => void) | undefined;
      const oldHintRequest = new Promise<{ hint: string }>((resolve) => {
        resolveOldHint = resolve;
      });
      vi.mocked(getStepQuiz)
        .mockResolvedValueOnce(oxQuiz)
        .mockResolvedValueOnce(multipleChoiceQuiz);
      vi.mocked(requestQuizHint).mockReturnValue(oldHintRequest);

      const { rerender } = render(
        <PlayPage
          review={{ step: 1, slot: 1, correct: 0, streak: 0, topic: "프로세스", single: false, resumeSlot: 1 }}
        />,
      );

      await screen.findByText(oxQuiz.questionText);
      fireEvent.click(screen.getByRole("button", { name: "힌트 보기" }));

      rerender(
        <PlayPage
          review={{ step: 1, slot: 2, correct: 0, streak: 0, topic: "프로세스", single: false, resumeSlot: 2 }}
        />,
      );
      await screen.findByText(multipleChoiceQuiz.questionText);

      await act(async () => {
        resolveOldHint?.({ hint: "이전 문제의 늦은 힌트입니다." });
      });

      expect(screen.queryByText("이전 문제의 늦은 힌트입니다.")).not.toBeInTheDocument();
      expect(screen.getByRole("button", { name: "힌트 보기" })).toBeEnabled();
    });

    it("힌트 요청 실패 시 답안을 유지하고 다시 요청할 수 있다", async () => {
      const hint = "프로세스가 자원을 소유하는 단위를 떠올려 보세요.";
      vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
      vi.mocked(requestQuizHint)
        .mockRejectedValueOnce(new Error("network"))
        .mockResolvedValueOnce({ hint });

      render(<PlayPage />);

      const answer = await screen.findByRole("radio", { name: "O" });
      fireEvent.click(answer);
      fireEvent.click(screen.getByRole("button", { name: "힌트 보기" }));

      expect(await screen.findByText("힌트를 불러오지 못했어요.")).toBeInTheDocument();
      expect(answer).toBeChecked();

      fireEvent.click(screen.getByRole("button", { name: "힌트 보기" }));

      expect(await screen.findByText(hint)).toBeInTheDocument();
      expect(requestQuizHint).toHaveBeenCalledTimes(2);
      expect(answer).toBeChecked();
    });

    it("힌트 API가 401을 반환하면 로그인으로 이동한다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
      vi.mocked(requestQuizHint).mockRejectedValue({ status: 401 });

      render(<PlayPage />);

      await screen.findByText(oxQuiz.questionText);
      fireEvent.click(screen.getByRole("button", { name: "힌트 보기" }));

      await waitFor(() => {
        expect(mockRouter.replace).toHaveBeenCalledWith("/login");
      });
    });

    it("저장형 한 문장 힌트와 기존 오답 재도전 힌트를 독립적으로 함께 유지한다", async () => {
      const hint = "동시 접근을 한 번에 하나로 제한하는 장치를 떠올려 보세요.";
      vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
      vi.mocked(requestQuizHint).mockResolvedValue({ hint });
      vi.mocked(submitQuizAnswer).mockResolvedValue({
        isCorrect: false,
        retryHint: { eliminatedChoiceId: 13, blankHints: null },
      });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("button", { name: "힌트 보기" }));
      expect(await screen.findByText(hint)).toBeInTheDocument();
      expect(screen.getAllByRole("radio")).toHaveLength(4);
      for (const choice of screen.getAllByRole("radio")) {
        expect(choice).toBeEnabled();
      }

      fireEvent.click(screen.getByRole("radio", { name: /뮤텍스/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      expect(await screen.findByText(/틀린 선택지 하나를 지웠어요/)).toBeInTheDocument();
      expect(screen.getByText(hint)).toBeInTheDocument();
      expect(screen.getByRole("radio", { name: /스택/ })).toBeDisabled();
      expect(requestQuizHint).toHaveBeenCalledTimes(1);
      expect(mockRouter.push).not.toHaveBeenCalled();
    });

    it("첫 오답 뒤 재도전 화면에서는 요청형 힌트를 새로 열 수 없다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
      vi.mocked(submitQuizAnswer).mockResolvedValue({
        isCorrect: false,
        retryHint: { eliminatedChoiceId: 13, blankHints: null },
      });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: /뮤텍스/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      expect(await screen.findByText(/틀린 선택지 하나를 지웠어요/)).toBeInTheDocument();
      expect(screen.getByRole("button", { name: "힌트 보기" })).toBeDisabled();
      expect(requestQuizHint).not.toHaveBeenCalled();
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
        // 재도전으로 맞혔으므로 retry=1이 붙는다 — 해설 화면이 특별 칭찬을 고르는 근거.
        expect(mockRouter.push).toHaveBeenCalledWith(
          "/insight?quizId=8&correct=true&streak=3&retry=1",
        );
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

  describe("해설 화면으로 넘길 값", () => {
    it("재도전으로 맞히면 retry=1을 실어 해설 화면이 특별 칭찬을 고르게 한다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
      vi.mocked(submitQuizAnswer)
        .mockResolvedValueOnce({
          isCorrect: false,
          retryHint: { eliminatedChoiceId: 12, blankHints: null },
        })
        .mockResolvedValueOnce({ isCorrect: true, retryHint: null });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: /뮤텍스/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await screen.findByText(/틀린 선택지 하나를 지웠어요/);
      fireEvent.click(screen.getByRole("radio", { name: /스택/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await waitFor(() => {
        expect(mockRouter.push).toHaveBeenCalledWith(
          "/insight?quizId=8&correct=true&streak=1&retry=1",
        );
      });
    });

    it("재도전 없이 맞히면 retry 파라미터를 붙이지 않는다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
      vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: "O" }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await waitFor(() => {
        expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=7&correct=true&streak=1");
      });
    });

    it("마지막 문제면 완주 요약 값을 URL에 싣는다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue({ ...oxQuiz, slotOrder: 5, totalCount: 5 });
      vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });
      window.localStorage.setItem(
        "thumbsup:play-session:1",
        JSON.stringify({ answered: 4, correct: 3, combo: 1, bestCombo: 2 }),
      );

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: "O" }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await waitFor(() => {
        expect(mockRouter.push).toHaveBeenCalledWith(
          "/insight?quizId=7&correct=true&streak=2&done=1&c=4&bc=2&a=5",
        );
      });
    });
  });

  describe("복습 화살표 내비게이션(이슈 303·304)", () => {
    it("복습이 아니면 화살표를 보여주지 않는다", async () => {
      vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);

      render(<PlayPage />);

      await screen.findByText(oxQuiz.questionText);
      expect(screen.queryByRole("link", { name: "이전 문제 다시 보기" })).not.toBeInTheDocument();
      expect(
        screen.queryByRole("link", { name: "정답 없이 다음 문제로 건너뛰기" }),
      ).not.toBeInTheDocument();
    });

    it("1번 슬롯(라이브 에지)에서는 이전 화살표가 비활성이고, 다음 화살표는 건너뛰기 링크다", async () => {
      vi.mocked(getStepQuiz).mockResolvedValue({ ...oxQuiz, slotOrder: 1 });

      render(
        <PlayPage
          review={{ step: 1, slot: 1, correct: 2, streak: 3, topic: "프로세스", single: false, resumeSlot: 1 }}
        />,
      );

      await screen.findByText(oxQuiz.questionText);

      const back = screen.getByRole("link", { name: "이전 문제 다시 보기" });
      expect(back).toHaveAttribute("aria-disabled", "true");

      const forward = screen.getByRole("link", { name: "정답 없이 다음 문제로 건너뛰기" });
      expect(forward).toHaveAttribute(
        "href",
        "/play?step=1&slot=2&rc=2&rs=0&topic=%ED%94%84%EB%A1%9C%EC%84%B8%EC%8A%A4&rsm=2",
      );
    });

    it("마지막 슬롯에서 건너뛰면 완료 요약으로 바로 간다", async () => {
      vi.mocked(getStepQuiz).mockResolvedValue({ ...oxQuiz, slotOrder: 5, totalCount: 5 });

      render(
        <PlayPage
          review={{ step: 1, slot: 5, correct: 3, streak: 2, topic: "프로세스", single: false, resumeSlot: 5 }}
        />,
      );

      await screen.findByText(oxQuiz.questionText);

      const forward = screen.getByRole("link", { name: "정답 없이 다음 문제로 건너뛰기" });
      expect(forward).toHaveAttribute(
        "href",
        "/history/done?step=1&slot=5&rc=3&rs=0&topic=%ED%94%84%EB%A1%9C%EC%84%B8%EC%8A%A4&rsm=5",
      );
    });

    it("미리보기 중(이전 슬롯)에는 재제출을 막고 다음 화살표는 그냥 한 칸 이동한다", async () => {
      vi.mocked(getStepQuiz).mockResolvedValue({ ...oxQuiz, slotOrder: 2 });

      render(
        <PlayPage
          review={{ step: 1, slot: 2, correct: 1, streak: 1, topic: "프로세스", single: false, resumeSlot: 4 }}
        />,
      );

      await screen.findByText(oxQuiz.questionText);

      expect(
        screen.getByText("이미 지나온 문제예요. 다시 채점하지 않아요 — 위 화살표로 이동해요."),
      ).toBeInTheDocument();
      expect(screen.queryByRole("button", { name: "정답 확인" })).not.toBeInTheDocument();
      expect(screen.queryByRole("button", { name: "힌트 보기" })).not.toBeInTheDocument();
      expect(screen.getByRole("radio", { name: "O" })).toBeDisabled();

      const back = screen.getByRole("link", { name: "이전 문제 다시 보기" });
      expect(back).toHaveAttribute(
        "href",
        "/play?step=1&slot=1&rc=1&rs=1&topic=%ED%94%84%EB%A1%9C%EC%84%B8%EC%8A%A4&rsm=4",
      );

      const forward = screen.getByRole("link", { name: "다음 문제 보기" });
      expect(forward).toHaveAttribute(
        "href",
        "/play?step=1&slot=3&rc=1&rs=1&topic=%ED%94%84%EB%A1%9C%EC%84%B8%EC%8A%A4&rsm=4",
      );
    });
  });
});
