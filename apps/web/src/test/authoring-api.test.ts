import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  approveDraft,
  generateDraft,
  getAuthoringCourseQuizzes,
  getAuthoringCourses,
  getAuthoringQuizzes,
  getDraft,
  getDrafts,
  getJob,
  improveQuiz,
  reviewDraft,
} from "@/features/authoring/api";
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
    method?: string;
    headers: Record<string, string>;
    body?: string;
  };
}

beforeEach(() => {
  localStorage.clear();
  vi.restoreAllMocks();
  tokenStore.set({ accessToken: "acc", refreshToken: "ref" });
});

describe("authoring api", () => {
  it("generateDraft가 올바른 경로·메서드·body로 호출하고 jobId를 반환한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { jobId: 7 })));
    vi.stubGlobal("fetch", fetchMock);

    const result = await generateDraft("운영체제");

    expect(result).toEqual({ jobId: 7 });
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/drafts/generate",
    );
    expect(callInit(fetchMock, 0).method).toBe("POST");
    expect(JSON.parse(callInit(fetchMock, 0).body as string)).toEqual({ topic: "운영체제" });
  });

  it("getDrafts(status)가 쿼리스트링을 포함하고 drafts 배열을 언랩한다", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(
        200,
        envelope("SUCCESS", {
          drafts: [
            {
              draftId: 1,
              origin: "NEW",
              status: "DRAFT",
              topic: "운영체제",
              sourceQuizId: null,
              revisionCount: 0,
              updatedAt: "2026-07-14T00:00:00Z",
            },
          ],
        }),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const drafts = await getDrafts("DRAFT");

    expect(drafts).toHaveLength(1);
    expect(drafts[0].draftId).toBe(1);
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/drafts?status=DRAFT",
    );
  });

  it("getDrafts()는 status 생략 시 쿼리스트링 없이 호출한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { drafts: [] })));
    vi.stubGlobal("fetch", fetchMock);

    await getDrafts();

    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/drafts",
    );
  });

  it("reviewDraft는 feedback 생략 시 body에서 필드를 제외한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { jobId: 9 })));
    vi.stubGlobal("fetch", fetchMock);

    const result = await reviewDraft(3);

    expect(result).toEqual({ jobId: 9 });
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/drafts/3/reviews",
    );
    expect(JSON.parse(callInit(fetchMock, 0).body as string)).toEqual({});
  });

  it("reviewDraft는 feedback 전달 시 body에 포함한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { jobId: 9 })));
    vi.stubGlobal("fetch", fetchMock);

    await reviewDraft(3, "선지 순서 바꿔줘");

    expect(JSON.parse(callInit(fetchMock, 0).body as string)).toEqual({
      feedback: "선지 순서 바꿔줘",
    });
  });

  it("improveQuiz가 올바른 경로로 instruction을 보내고 draftId·jobId를 반환한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(200, envelope("SUCCESS", { draftId: 5, jobId: 11 })));
    vi.stubGlobal("fetch", fetchMock);

    const result = await improveQuiz(42, "설명을 더 쉽게");

    expect(result).toEqual({ draftId: 5, jobId: 11 });
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/quizzes/42/improve",
    );
    expect(JSON.parse(callInit(fetchMock, 0).body as string)).toEqual({
      instruction: "설명을 더 쉽게",
    });
  });

  it("approveDraft가 draftId·status를 반환한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(
        jsonResponse(200, envelope("SUCCESS", { draftId: 3, status: "APPROVED" })),
      );
    vi.stubGlobal("fetch", fetchMock);

    const result = await approveDraft(3);

    expect(result).toEqual({ draftId: 3, status: "APPROVED" });
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/drafts/3/approve",
    );
    expect(callInit(fetchMock, 0).method).toBe("POST");
  });

  it("getDraft가 상세(revision 이력 포함)를 반환한다", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(
        200,
        envelope("SUCCESS", {
          draftId: 3,
          origin: "NEW",
          status: "DRAFT",
          topic: "운영체제",
          sourceQuizId: null,
          revisionCount: 1,
          updatedAt: "2026-07-14T00:00:00Z",
          payload: { quizzes: [] },
          revisions: [
            {
              revisionNo: 1,
              reviewSummary: "선지 순서 수정",
              reviewedBy: 2,
              jobId: 10,
              createdAt: "2026-07-14T00:00:00Z",
            },
          ],
          createdBy: 1,
          approvedBy: null,
          approvedAt: null,
        }),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const draft = await getDraft(3);

    expect(draft.draftId).toBe(3);
    expect(draft.revisions).toHaveLength(1);
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/drafts/3",
    );
  });

  it("getAuthoringQuizzes가 steps 배열을 언랩한다", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(
        200,
        envelope("SUCCESS", {
          steps: [
            {
              stepOrder: 1,
              topic: "운영체제",
              quizzes: [
                { quizId: 1, slotOrder: 1, type: "OX", difficulty: "EASY", questionText: "..." },
              ],
            },
          ],
        }),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const steps = await getAuthoringQuizzes();

    expect(steps).toHaveLength(1);
    expect(steps[0].quizzes[0].quizId).toBe(1);
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/quizzes",
    );
  });

  it("getJob이 잡 상태를 반환한다", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(
        200,
        envelope("SUCCESS", {
          jobId: 7,
          kind: "GENERATE",
          status: "RUNNING",
          draftId: null,
          error: null,
          createdAt: "2026-07-14T00:00:00Z",
          startedAt: "2026-07-14T00:00:01Z",
          finishedAt: null,
        }),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const job = await getJob(7);

    expect(job.status).toBe("RUNNING");
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/jobs/7",
    );
  });

  it("getAuthoringCourses가 courses 배열을 언랩한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(
        jsonResponse(
          200,
          envelope("SUCCESS", { courses: [{ courseId: 1, title: "운영체제", category: "CS" }] }),
        ),
      );
    vi.stubGlobal("fetch", fetchMock);

    const result = await getAuthoringCourses();

    expect(result).toEqual([{ courseId: 1, title: "운영체제", category: "CS" }]);
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/courses",
    );
  });

  it("getAuthoringCourseQuizzes가 courseId 경로로 상세를 반환한다", async () => {
    const detail = { courseId: 1, title: "운영체제", steps: [] };
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(200, envelope("SUCCESS", detail)));
    vi.stubGlobal("fetch", fetchMock);

    const result = await getAuthoringCourseQuizzes(1);

    expect(result).toEqual(detail);
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/courses/1/quizzes",
    );
  });
});
