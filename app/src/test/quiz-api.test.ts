import { beforeEach, describe, expect, it, vi } from "vitest";
import { getNextQuiz, getQuizExplanation, requestQuizHint, submitQuizAnswer } from "@/lib/api/quiz";
import { tokenStore } from "@/lib/api/token-store";

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function envelope(code: string, data: unknown = null, message = "OK") {
  return { code, message, data, meta: null };
}

function callInit(mock: ReturnType<typeof vi.fn>, index: number) {
  return mock.mock.calls[index][1] as {
    headers: Record<string, string>;
    body?: string;
    method?: string;
  };
}

beforeEach(() => {
  localStorage.clear();
  vi.restoreAllMocks();
});

describe("quiz api", () => {
  it("fetches the next quiz through the shared authenticated API client", async () => {
    tokenStore.set({ accessToken: "acc", refreshToken: "ref" });
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(
        200,
        envelope("SUCCESS", {
          quizId: 7,
          type: "OX",
          difficulty: "EASY",
          questionText: "프로세스는 자원을 독립적으로 가진다.",
          codeSnippet: null,
          choices: null,
          blankCount: null,
          stepOrder: 1,
          slotOrder: 2,
        }),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const quiz = await getNextQuiz();

    expect(quiz.quizId).toBe(7);
    expect(String(fetchMock.mock.calls[0][0])).toContain("/api/v1/quizzes/next");
    expect(callInit(fetchMock, 0).headers.Authorization).toBe("Bearer acc");
  });

  it("코스를 지정하면 courseId 쿼리로 다음 문제를 요청한다", async () => {
    tokenStore.set({ accessToken: "acc", refreshToken: "ref" });
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(
        200,
        envelope("SUCCESS", {
          quizId: 20,
          type: "OX",
          difficulty: "EASY",
          questionText: "싱글턴은 전역 상태를 만든다.",
          codeSnippet: null,
          choices: null,
          blankCount: null,
          stepOrder: 13,
          slotOrder: 1,
        }),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    await getNextQuiz(2);

    expect(String(fetchMock.mock.calls[0][0])).toContain("/api/v1/quizzes/next?courseId=2");
  });

  it("submits answers as ordered string values", async () => {
    tokenStore.set({ accessToken: "acc", refreshToken: "ref" });
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { isCorrect: true })));
    vi.stubGlobal("fetch", fetchMock);

    const result = await submitQuizAnswer(7, ["O"]);

    expect(result).toEqual({ isCorrect: true });
    expect(String(fetchMock.mock.calls[0][0])).toContain("/api/v1/quizzes/7/answers");
    expect(JSON.parse(callInit(fetchMock, 0).body as string)).toEqual({ answers: ["O"] });
  });

  it("requests the stored one-sentence hint through the shared authenticated API client", async () => {
    tokenStore.set({ accessToken: "acc", refreshToken: "ref" });
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(
        200,
        envelope("SUCCESS", {
          hint: "프로세스가 자원을 소유하는 단위를 떠올려 보세요.",
        }),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const result = await requestQuizHint(7);

    expect(result).toEqual({ hint: "프로세스가 자원을 소유하는 단위를 떠올려 보세요." });
    expect(String(fetchMock.mock.calls[0][0])).toContain("/api/v1/quizzes/7/hints");
    expect(callInit(fetchMock, 0)).toMatchObject({
      method: "POST",
      headers: { Authorization: "Bearer acc" },
    });
    expect(callInit(fetchMock, 0).body).toBeUndefined();
  });

  it("fetches quiz explanation with server-provided highlight offsets", async () => {
    tokenStore.set({ accessToken: "acc", refreshToken: "ref" });
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(
        200,
        envelope("SUCCESS", {
          quizId: 7,
          questionText: "프로세스는 자원을 독립적으로 가진다.",
          type: "OX",
          difficulty: "EASY",
          currentNumber: 2,
          totalCount: 5,
          courseTitle: "운영체제",
          unitTitle: "프로세스와 스레드",
          explanationSummary: [
            {
              text: "프로세스는 독립된 자원 단위다.",
              highlights: [{ keyword: "프로세스", start: 0, end: 4 }],
            },
          ],
          explanationExample: null,
          wrongAnswerExplanation: {
            text: "스레드는 같은 프로세스의 자원을 공유한다.",
            highlights: [{ keyword: "스레드", start: 0, end: 3 }],
          },
          keywords: [
            { keyword: "프로세스", description: "운영체제가 자원을 관리하는 실행 단위" },
            { keyword: "스레드", description: "프로세스 안의 실행 흐름" },
          ],
          followUpQuestions: [
            {
              followUpQuestionId: 10,
              content: "스레드가 자원을 공유하면 어떤 문제가 생길까요?",
              isPrimary: true,
            },
          ],
        }),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const explanation = await getQuizExplanation(7);

    expect(explanation.explanationSummary[0].highlights[0]).toEqual({
      keyword: "프로세스",
      start: 0,
      end: 4,
    });
    expect(explanation.followUpQuestions[0]).toEqual({
      followUpQuestionId: 10,
      content: "스레드가 자원을 공유하면 어떤 문제가 생길까요?",
      isPrimary: true,
    });
    expect(String(fetchMock.mock.calls[0][0])).toContain("/api/v1/quizzes/7/explanation");
  });
});
