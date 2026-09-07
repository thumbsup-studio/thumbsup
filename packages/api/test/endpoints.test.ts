import { beforeEach, describe, expect, it, vi } from "vitest";
import { createApiClient } from "../src";
import { callInit, createMemoryTokenStorage, envelope, jsonResponse } from "./fixtures";

beforeEach(() => {
  vi.restoreAllMocks();
});

describe("endpoint APIs", () => {
  it("history graph를 인증 요청으로 조회한다", async () => {
    const storage = createMemoryTokenStorage({ accessToken: "acc", refreshToken: "ref" });
    const client = createApiClient({ baseUrl: "https://api.example.com", tokenStorage: storage });
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(
        200,
        envelope("SUCCESS", {
          nodes: [{ id: "process", description: ["실행 단위"] }],
          edges: [],
        }),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const graph = await client.getHistoryGraph();

    expect(graph.nodes[0]?.description).toEqual(["실행 단위"]);
    expect(fetchMock.mock.calls[0]?.[0]).toContain("/api/v1/history/graph");
    expect(callInit(fetchMock, 0).headers.Authorization).toBe("Bearer acc");
  });

  it("quiz endpoint의 경로와 요청 본문을 유지한다", async () => {
    const client = createApiClient({
      baseUrl: "https://api.example.com",
      tokenStorage: createMemoryTokenStorage({ accessToken: "acc", refreshToken: "ref" }),
    });
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(jsonResponse(200, envelope("SUCCESS", { quizId: 7 })))
      .mockResolvedValueOnce(jsonResponse(200, envelope("SUCCESS", { isCorrect: true })));
    vi.stubGlobal("fetch", fetchMock);

    await client.getNextQuiz(2);
    await expect(client.submitQuizAnswer(7, ["O"])).resolves.toEqual({ isCorrect: true });

    expect(fetchMock.mock.calls[0]?.[0]).toContain("/api/v1/quizzes/next?courseId=2");
    expect(fetchMock.mock.calls[1]?.[0]).toContain("/api/v1/quizzes/7/answers");
    expect(JSON.parse(callInit(fetchMock, 1).body as string)).toEqual({ answers: ["O"] });
  });

  it("현재 코스의 다음 스텝 브리핑을 요청한다", async () => {
    const client = createApiClient({
      baseUrl: "https://api.example.com",
      tokenStorage: createMemoryTokenStorage(),
    });
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { quizStepId: 42, blocks: [] })));
    vi.stubGlobal("fetch", fetchMock);

    await expect(client.getNextStepBriefing(2)).resolves.toMatchObject({ quizStepId: 42 });
    expect(fetchMock.mock.calls[0]?.[0]).toContain("/api/v1/courses/2/next-step/briefing");
  });

  it("quizStepId로 스텝의 다음 문제를 요청한다", async () => {
    const client = createApiClient({
      baseUrl: "https://api.example.com",
      tokenStorage: createMemoryTokenStorage(),
    });
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { quizId: 20 })));
    vi.stubGlobal("fetch", fetchMock);

    await client.getNextQuizForStep(42);

    expect(fetchMock.mock.calls[0]?.[0]).toContain("/api/v1/quiz-steps/42/quizzes/next");
  });

  it("저장된 한 문장 힌트를 POST로 요청한다", async () => {
    const client = createApiClient({
      baseUrl: "https://api.example.com",
      tokenStorage: createMemoryTokenStorage(),
    });
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { hint: "힌트 문장" })));
    vi.stubGlobal("fetch", fetchMock);

    await expect(client.requestQuizHint(7)).resolves.toEqual({ hint: "힌트 문장" });
    expect(callInit(fetchMock, 0)).toMatchObject({ method: "POST" });
    expect(fetchMock.mock.calls[0]?.[0]).toContain("/api/v1/quizzes/7/hints");
  });

  it("해설 응답의 하이라이트 위치를 그대로 반환한다", async () => {
    const client = createApiClient({
      baseUrl: "https://api.example.com",
      tokenStorage: createMemoryTokenStorage(),
    });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        jsonResponse(
          200,
          envelope("SUCCESS", {
            explanationSummary: [
              { text: "프로세스", highlights: [{ keyword: "프로세스", start: 0, end: 4 }] },
            ],
            followUpQuestions: [],
          }),
        ),
      ),
    );

    const explanation = await client.getQuizExplanation(7);

    expect(explanation.explanationSummary[0]?.highlights[0]).toEqual({
      keyword: "프로세스",
      start: 0,
      end: 4,
    });
  });

  it("꼬리 질문 상세를 인증 경로로 조회한다", async () => {
    const client = createApiClient({
      baseUrl: "https://api.example.com",
      tokenStorage: createMemoryTokenStorage({ accessToken: "acc", refreshToken: "ref" }),
    });
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(200, envelope("SUCCESS", { followUpQuestionId: 12, question: "왜일까요?" })),
    );
    vi.stubGlobal("fetch", fetchMock);

    await expect(client.getFollowUpQuestion(12)).resolves.toMatchObject({
      followUpQuestionId: 12,
    });
    expect(fetchMock.mock.calls[0]?.[0]).toContain("/api/v1/follow-up-questions/12");
    expect(callInit(fetchMock, 0).headers.Authorization).toBe("Bearer acc");
  });

  it("코스 목록과 의견 보내기도 같은 transport를 사용한다", async () => {
    const client = createApiClient({
      baseUrl: "https://api.example.com",
      tokenStorage: createMemoryTokenStorage(),
    });
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(jsonResponse(200, envelope("SUCCESS", { items: [] })))
      .mockResolvedValueOnce(jsonResponse(200, envelope("SUCCESS", { id: 9 })));
    vi.stubGlobal("fetch", fetchMock);

    await expect(client.getCourses()).resolves.toEqual({ items: [] });
    await expect(client.sendFeedback("좋아요")).resolves.toEqual({ id: 9 });

    expect(fetchMock.mock.calls[0]?.[0]).toContain("/api/v1/courses");
    expect(JSON.parse(callInit(fetchMock, 1).body as string)).toEqual({ content: "좋아요" });
  });
});
