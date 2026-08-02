import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  addOutlineStep,
  createOutline,
  deleteOutlineStep,
  generateStepQuizzes,
  getOutline,
  getOutlines,
  publishOutline,
  regenerateOutline,
  reorderOutlineStep,
  updateOutline,
  updateOutlineStep,
} from "@/features/authoring/api";
import { tokenStore } from "@/lib/api/token-store";

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function envelope(data: unknown) {
  return { code: "SUCCESS", message: "OK", data, meta: null };
}

function callInit(mock: ReturnType<typeof vi.fn>, index = 0) {
  return mock.mock.calls[index][1] as { method?: string; body?: string };
}

beforeEach(() => {
  localStorage.clear();
  vi.restoreAllMocks();
  tokenStore.set({ accessToken: "acc", refreshToken: "ref" });
});

describe("authoring outline api", () => {
  it("createOutline은 제목·분류·목차를 POST하고 잡 정보를 반환한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonResponse(202, envelope({ outlineId: 1, jobId: 7 })));
    vi.stubGlobal("fetch", fetchMock);

    await expect(createOutline("네트워크", "CS", "1장 구조")).resolves.toEqual({
      outlineId: 1,
      jobId: 7,
    });
    expect(String(fetchMock.mock.calls[0][0])).toContain("/authoring/outlines");
    expect(callInit(fetchMock).method).toBe("POST");
    expect(JSON.parse(callInit(fetchMock).body as string)).toEqual({
      title: "네트워크",
      category: "CS",
      toc: "1장 구조",
    });
  });

  it("getOutlines는 data.outlines를 언랩한다", async () => {
    const outlines = [
      {
        outlineId: 1,
        title: "네트워크",
        category: "CS",
        status: "DRAFT",
        stepCount: 5,
        approvedStepCount: 2,
      },
    ];
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(200, envelope({ outlines })));
    vi.stubGlobal("fetch", fetchMock);

    await expect(getOutlines()).resolves.toEqual(outlines);
  });

  it("getOutline은 상세를 반환한다", async () => {
    const detail = {
      outlineId: 1,
      title: "네트워크",
      category: "CS",
      status: "DRAFT",
      toc: null,
      steps: [],
    };
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(200, envelope(detail)));
    vi.stubGlobal("fetch", fetchMock);

    await expect(getOutline(1)).resolves.toEqual(detail);
    expect(String(fetchMock.mock.calls[0][0])).toContain("/authoring/outlines/1");
  });

  it("뼈대 수정·재생성·발행 API가 계약 경로와 body를 사용한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(jsonResponse(200, envelope(null)))
      .mockResolvedValueOnce(jsonResponse(202, envelope({ jobId: 8 })))
      .mockResolvedValueOnce(jsonResponse(200, envelope({ courseId: 3, stepCount: 5 })));
    vi.stubGlobal("fetch", fetchMock);

    await updateOutline(1, { title: "새 제목" });
    await expect(regenerateOutline(1)).resolves.toEqual({ jobId: 8 });
    await expect(publishOutline(1)).resolves.toEqual({ courseId: 3, stepCount: 5 });

    expect(String(fetchMock.mock.calls[0][0])).toContain("/authoring/outlines/1");
    expect(callInit(fetchMock, 0).method).toBe("PATCH");
    expect(JSON.parse(callInit(fetchMock, 0).body as string)).toEqual({ title: "새 제목" });
    expect(String(fetchMock.mock.calls[1][0])).toContain("/authoring/outlines/1/outline-jobs");
    expect(String(fetchMock.mock.calls[2][0])).toContain("/authoring/outlines/1/publish");
  });

  it("스텝 추가·수정·삭제·순서 변경·문제 생성 API를 호출한다", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(jsonResponse(202, envelope({ stepId: 11 })))
      .mockResolvedValueOnce(jsonResponse(200, envelope(null)))
      .mockResolvedValueOnce(jsonResponse(200, envelope(null)))
      .mockResolvedValueOnce(jsonResponse(200, envelope(null)))
      .mockResolvedValueOnce(jsonResponse(202, envelope({ jobId: 12 })));
    vi.stubGlobal("fetch", fetchMock);

    await expect(addOutlineStep(1, "TCP/IP")).resolves.toEqual({ stepId: 11 });
    await updateOutlineStep(11, "TCP/IP 4계층");
    await deleteOutlineStep(11);
    await reorderOutlineStep(11, "UP");
    await expect(generateStepQuizzes(11, "BASIC_5")).resolves.toEqual({ jobId: 12 });

    expect(String(fetchMock.mock.calls[0][0])).toContain("/authoring/outlines/1/steps");
    expect(JSON.parse(callInit(fetchMock, 0).body as string)).toEqual({ topic: "TCP/IP" });
    expect(String(fetchMock.mock.calls[1][0])).toContain("/authoring/outline-steps/11");
    expect(String(fetchMock.mock.calls[2][0])).toContain("/authoring/outline-steps/11");
    expect(callInit(fetchMock, 2).method).toBe("DELETE");
    expect(JSON.parse(callInit(fetchMock, 3).body as string)).toEqual({ direction: "UP" });
    expect(JSON.parse(callInit(fetchMock, 4).body as string)).toEqual({ preset: "BASIC_5" });
  });
});
