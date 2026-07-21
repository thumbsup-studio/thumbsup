import { describe, expect, it } from "vitest";
import type { CliAdapter } from "../src/adapters/types.js";
import { applyEdits, buildEditPrompt, buildJudgePrompt, drainAnalysisQueue, fetchThread, type AnalysisDeps } from "../src/analysis.js";
import { openDb } from "../src/db.js";
import type { GhClient } from "../src/github.js";

describe("applyEdits", () => {
  it("정확히 1건 매치면 치환한다", () => {
    expect(applyEdits("a b c", [{ old: "b", new: "B" }])).toBe("a B c");
  });
  it("매치 0건이면 throw", () => {
    expect(() => applyEdits("a b c", [{ old: "z", new: "Z" }])).toThrow(/0건/);
  });
  it("매치 2건 이상이면 throw — 조용히 틀린 파일 생성 금지", () => {
    expect(() => applyEdits("a b b", [{ old: "b", new: "B" }])).toThrow(/2건/);
  });
  it("순차 적용 — 앞 치환 결과에 뒤 치환이 적용된다", () => {
    expect(applyEdits("x y", [{ old: "x", new: "y" }, { old: "y y", new: "done" }])).toBe("done");
  });
});

describe("buildJudgePrompt", () => {
  const base = {
    thread: [{ user: "U1", text: "북마크 3순위로 미루자" }],
    permalink: "https://slack/p1",
    hits: [{ file: "spec.md", heading: "우선순위", ids: ["F-45"], body: "북마크는 2순위" }],
    openIssues: [{ number: 3, title: "북마크 UI", labels: ["app"] }],
    areaOptions: ["S2 홈", "S7 정리장"],
    statusOptions: ["Todo", "Done"],
  };
  it("스레드·명세 발췌·열린 이슈·permalink를 프롬프트에 담는다", () => {
    const { prompt } = buildJudgePrompt(base);
    expect(prompt).toContain("북마크 3순위로 미루자");
    expect(prompt).toContain("북마크는 2순위");
    expect(prompt).toContain("#3 북마크 UI");
    expect(prompt).toContain("https://slack/p1");
  });
  it("area·status 스키마 enum은 보드 옵션을 그대로 쓴다", () => {
    const { outputSchema } = buildJudgePrompt(base);
    const s = JSON.stringify(outputSchema);
    expect(s).toContain("S7 정리장");
    expect(s).toContain("Todo");
  });
  it("prev가 있으면 중복 등록 방지 지시를 담는다", () => {
    const { prompt } = buildJudgePrompt({ ...base, prev: { prUrl: "https://gh/pr/1", issueUrls: ["https://gh/i/2"] } });
    expect(prompt).toContain("https://gh/pr/1");
    expect(prompt).toContain("https://gh/i/2");
  });
});

describe("buildEditPrompt", () => {
  it("파일 내용과 지시를 담고 edits 스키마를 요구한다", () => {
    const { prompt, outputSchema } = buildEditPrompt({ file: "spec.md", content: "# 제목\n본문", instruction: "순위를 3으로" });
    expect(prompt).toContain("# 제목");
    expect(prompt).toContain("순위를 3으로");
    expect(JSON.stringify(outputSchema)).toContain("edits");
  });
});

/** 스레드 페이지 응답과 postMessage 기록을 갖춘 테스트 하네스 */
function harness(over: Partial<{ threadMsgs: Array<{ ts: string; user?: string; text?: string }>; judgeJson: object; editJson: object }> = {}) {
  const db = openDb(":memory:");
  const posted: string[] = [];
  const ghCalls: string[] = [];
  const prompts: string[] = []; // adapter.run에 전달된 prompt 기록 — prev 동봉 여부 검증용
  const closePrCalls: Array<{ prNumber: number; comment: string }> = [];
  const submitSpecPrCalls: Array<{ branch: string }> = [];
  const judge = over.judgeJson ?? { spec_changes: [], issue_actions: [], nothing_found: true };
  const adapterOutputs = [JSON.stringify(judge), JSON.stringify(over.editJson ?? { edits: [{ old: "2순위", new: "3순위" }] })];
  let adapterCall = 0;
  const deps: AnalysisDeps = {
    db,
    adapter: {
      run: async (input) => {
        prompts.push(input.prompt);
        return adapterOutputs[Math.min(adapterCall++, 1)]!;
      },
    } as CliAdapter,
    index: [{ file: "spec.md", heading: "h", ids: [], body: "북마크는 2순위" }],
    history: {
      history: async () => ({ messages: [] }),
      replies: async ({ channel }) => ({
        messages: (over.threadMsgs ?? [{ ts: "1.0", user: "U1", text: "북마크 미루자" }]).map((m) => ({ channel, ts: m.ts, user: m.user, text: m.text })),
      }),
    },
    gh: {
      listOpenIssues: async () => { ghCalls.push("list"); return []; },
      boardOptions: async () => ({ area: ["S2 홈"], status: ["Todo"] }),
      createIssue: async () => { ghCalls.push("createIssue"); return { number: 42, url: "https://gh/i/42" }; },
      commentIssue: async () => { ghCalls.push("commentIssue"); return { url: "https://gh/i/3#c" }; },
      setBoardFields: async () => { ghCalls.push("setBoardFields"); },
      checkAuth: async () => ({ ok: true, login: "kmjnnhyk" }),
      prepareSpecRepo: async () => { ghCalls.push("prepare"); },
      readSpecFile: async () => "북마크는 2순위",
      submitSpecPr: async (args) => {
        ghCalls.push("submitSpecPr");
        submitSpecPrCalls.push({ branch: args.branch });
        return { number: 9, url: "https://gh/pr/9" };
      },
      mergePr: async () => {},
      closePr: async (prNumber, comment) => {
        ghCalls.push("closePr");
        closePrCalls.push({ prNumber, comment });
      },
    } as GhClient,
    getPermalink: async () => "https://slack/p1",
    postMessage: async (_c, _t, text) => { posted.push(text); return { ts: `bot.${posted.length}` }; },
    log: () => {},
  };
  return { db, deps, posted, ghCalls, prompts, closePrCalls, submitSpecPrCalls };
}

describe("fetchThread", () => {
  it("봇 메시지(user 없음)도 포함하고 마지막 ts를 계산한다", async () => {
    const { deps } = harness({ threadMsgs: [{ ts: "1.0", user: "U1", text: "질문" }, { ts: "2.0", text: "AI 허들 요약" }] });
    const t = await fetchThread(deps.history, "C1", "1.0");
    expect(t.msgs).toEqual([{ user: "U1", text: "질문" }, { user: "bot", text: "AI 허들 요약" }]);
    expect(t.lastMsgTs).toBe("2.0");
  });
});

describe("drainAnalysisQueue", () => {
  it("nothing_found면 '찾지 못했다' 답글 후 done", async () => {
    const { db, deps, posted } = harness();
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    expect(await drainAnalysisQueue(deps)).toBe(1);
    expect(posted[0]).toContain("찾지 못했");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" })).toBe("queued"); // done 상태였음
  });

  it("spec_changes는 PR 생성 → 승인 대기 답글 ts를 spec_prs에 기록한다", async () => {
    const { db, deps, posted, ghCalls } = harness({
      judgeJson: { spec_changes: [{ file: "spec.md", summary: "북마크 연기", rationale: "합의", edit_instruction: "2순위를 3순위로" }], issue_actions: [], nothing_found: false },
    });
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);
    expect(ghCalls).toContain("prepare");
    expect(ghCalls).toContain("submitSpecPr");
    expect(posted.some((p) => p.includes("https://gh/pr/9"))).toBe(true);
    // 승인 대기 답글(첫 게시)의 ts로 역참조 가능해야 한다
    expect(db.specPrByMessage("C1", "bot.1")?.prNumber).toBe(9);
  });

  it("submitSpecPr에 전달된 branch가 lastMsgTs를 포함한다 (재분석마다 고유 브랜치)", async () => {
    const { db, deps, submitSpecPrCalls } = harness({
      threadMsgs: [{ ts: "1.0", user: "U1", text: "북마크 미루자" }, { ts: "3.5", user: "U2", text: "네 좋아요" }],
      judgeJson: { spec_changes: [{ file: "spec.md", summary: "s", rationale: "r", edit_instruction: "2순위를 3순위로" }], issue_actions: [], nothing_found: false },
    });
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);
    expect(submitSpecPrCalls[0]?.branch).toBe("docs/pm-bot-1-0-3-5");
  });

  it("기존 awaiting spec_pr이 있는 스레드 재분석 → closePr 호출 + 기존 행 superseded + 새 행 insert + 답글에 대체 문구", async () => {
    const { db, deps, posted, closePrCalls } = harness({
      judgeJson: { spec_changes: [{ file: "spec.md", summary: "북마크 연기", rationale: "합의", edit_instruction: "2순위를 3순위로" }], issue_actions: [], nothing_found: false },
    });
    db.insertSpecPr({ prNumber: 5, prUrl: "https://gh/pr/5", channel: "C1", messageTs: "old.1", threadTs: "1.0", status: "awaiting" });
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);

    expect(closePrCalls).toEqual([{ prNumber: 5, comment: expect.stringContaining("superseded") }]);
    expect(db.specPrByMessage("C1", "old.1")?.status).toBe("superseded"); // 기존 행은 superseded로, 승인·반려 대상에서 빠짐
    expect(db.specPrByMessage("C1", "bot.1")?.prNumber).toBe(9); // 새 PR이 새 행으로 기록됨
    expect(posted[0]).toContain("https://gh/pr/5");
    expect(posted[0]).toContain("대체되어 닫혔어요");
  });

  it("awaiting 아닌 기존 spec_pr(approved 등)은 재분석 때 건드리지 않는다", async () => {
    const { db, deps, posted, closePrCalls } = harness({
      judgeJson: { spec_changes: [{ file: "spec.md", summary: "s", rationale: "r", edit_instruction: "2순위를 3순위로" }], issue_actions: [], nothing_found: false },
    });
    db.insertSpecPr({ prNumber: 5, prUrl: "https://gh/pr/5", channel: "C1", messageTs: "old.1", threadTs: "1.0", status: "approved" });
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);

    expect(closePrCalls).toEqual([]);
    expect(db.specPrByMessage("C1", "old.1")?.status).toBe("approved");
    expect(posted[0]).not.toContain("대체되어 닫혔어요");
  });

  it("spec_changes.file에 경로 문자가 있으면 failed 처리하고 submitSpecPr을 호출하지 않는다", async () => {
    const { db, deps, posted, ghCalls } = harness({
      judgeJson: { spec_changes: [{ file: "../evil.md", summary: "s", rationale: "r", edit_instruction: "x" }], issue_actions: [], nothing_found: false },
    });
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);

    expect(ghCalls).not.toContain("submitSpecPr");
    const warn = posted.find((p) => p.includes("⚠️"))!;
    expect(warn).toContain("경로 문자");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" })).toBe("queued"); // failed → 재시도 가능
  });

  it("issue create는 등록 + 보드 배치 + 사후 보고", async () => {
    const { db, deps, posted, ghCalls } = harness({
      judgeJson: { spec_changes: [], issue_actions: [{ kind: "create", title: "t", body: "b", area: "S2 홈", status: "Todo" }], nothing_found: false },
    });
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);
    expect(ghCalls).toEqual(expect.arrayContaining(["createIssue", "setBoardFields"]));
    expect(posted.some((p) => p.includes("https://gh/i/42"))).toBe(true);
  });

  it("done 재큐잉 + 새 메시지 없음 → '이미 처리됨' 답글만 하고 done 복원", async () => {
    const { db, deps, posted, ghCalls } = harness();
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "1.0");
    db.markAnalysisDone("C1", "1.0", "1.0", '{"prUrl":"https://gh/pr/9","issueUrls":[]}'); // lastMsgTs = 스레드 마지막과 동일
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U2" });
    await drainAnalysisQueue(deps);
    expect(posted[0]).toContain("이미 처리");
    expect(posted[0]).toContain("https://gh/pr/9");
    expect(ghCalls).not.toContain("list"); // 판정까지 안 감
  });

  it("gh 비활성이면 failed + 안내 답글", async () => {
    const { db, deps, posted } = harness();
    deps.gh = null;
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);
    expect(posted[0]).toContain("GitHub 연동");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" })).toBe("queued"); // failed → 재시도 가능
  });

  it("이슈 단계 실패 시 성공한 PR 링크를 포함해 ⚠️ 보고하고 failed", async () => {
    const { db, deps, posted } = harness({
      judgeJson: {
        spec_changes: [{ file: "spec.md", summary: "s", rationale: "r", edit_instruction: "2순위를 3순위로" }],
        issue_actions: [{ kind: "create", title: "t", body: "b", area: "S2 홈", status: "Todo" }],
        nothing_found: false,
      },
    });
    deps.gh = { ...deps.gh!, createIssue: async () => { throw new Error("boom"); } };
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);
    const warn = posted.find((p) => p.includes("⚠️"))!;
    expect(warn).toContain("boom");
    expect(warn).toContain("https://gh/pr/9");
  });

  it("부분 실패 후 재드레인 — 성공한 PR 링크가 result_json에 보존되고 재판정 prompt에 동봉된다", async () => {
    const { db, deps, posted, prompts } = harness({
      judgeJson: {
        spec_changes: [{ file: "spec.md", summary: "s", rationale: "r", edit_instruction: "2순위를 3순위로" }],
        issue_actions: [{ kind: "create", title: "t", body: "b", area: "S2 홈", status: "Todo" }],
        nothing_found: false,
      },
    });
    deps.gh = { ...deps.gh!, createIssue: async () => { throw new Error("boom"); } };
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);
    expect(posted.some((p) => p.includes("⚠️"))).toBe(true);

    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" }); // 재큐잉
    expect(db.nextPendingAnalysis()?.resultJson).toContain("https://gh/pr/9"); // 실패해도 성공한 PR은 안 잃어버림

    await drainAnalysisQueue(deps);
    expect(prompts.some((p) => p.includes("https://gh/pr/9"))).toBe(true); // 재판정 prompt에 이전 PR 링크 동봉 → 중복 생성 방지
  });

  it("부분 실패 후 재시도 성공 — 1차 PR 링크와 2차 이슈 링크가 모두 result_json에 남고 done으로 종료된다", async () => {
    const { db, deps, posted } = harness({
      judgeJson: {
        spec_changes: [{ file: "spec.md", summary: "s", rationale: "r", edit_instruction: "2순위를 3순위로" }],
        issue_actions: [{ kind: "create", title: "t", body: "b", area: "S2 홈", status: "Todo" }],
        nothing_found: false,
      },
    });
    deps.gh = { ...deps.gh!, createIssue: async () => { throw new Error("boom"); } };
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps); // 1차: 명세 PR 생성 성공, 이슈 생성 실패 → failed (PR 링크는 result_json에 보존)

    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" }); // 재큐잉

    // 2차: 이슈 생성이 성공하도록 교체 + 어댑터가 이번엔 이슈 생성만 판정하도록 교체
    deps.gh = { ...deps.gh!, createIssue: async () => ({ number: 43, url: "https://gh/i/43" }) };
    deps.adapter = {
      run: async () =>
        JSON.stringify({ spec_changes: [], issue_actions: [{ kind: "create", title: "t", body: "b", area: "S2 홈", status: "Todo" }], nothing_found: false }),
    } as CliAdapter;

    const postedBefore = posted.length;
    await drainAnalysisQueue(deps);
    const secondRunPosts = posted.slice(postedBefore);
    expect(secondRunPosts.some((p) => p.includes("⚠️"))).toBe(false); // 2차는 성공 — 경고 없음
    expect(secondRunPosts.some((p) => p.includes("https://gh/i/43"))).toBe(true);

    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" })).toBe("queued"); // done 상태였다는 방증
    const row = db.nextPendingAnalysis();
    expect(row?.resultJson).toContain("https://gh/pr/9"); // 1차의 PR 링크 보존
    expect(row?.resultJson).toContain("https://gh/i/43"); // 2차의 이슈 링크 추가
  });

  it("done 이후 새 메시지가 있으면 '이미 처리' 단락 없이 재판정하고 prev 링크를 동봉한다", async () => {
    const { db, deps, posted, ghCalls, prompts } = harness(); // 기본 스레드 마지막 ts = "1.0"
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "1.0");
    db.markAnalysisDone("C1", "1.0", "0.5", '{"prUrl":"https://gh/pr/9","issueUrls":[]}'); // lastMsgTs가 스레드 마지막(1.0)보다 과거
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U2" });
    await drainAnalysisQueue(deps);
    expect(posted[0]).not.toContain("이미 처리");
    expect(ghCalls).toContain("list"); // 판정 단계까지 감
    expect(prompts.some((p) => p.includes("https://gh/pr/9"))).toBe(true);
  });

  it("postMessage가 계속 실패해도 drain은 예외를 던지지 않고 log에 남긴다", async () => {
    const { db, deps } = harness();
    const logs: string[] = [];
    deps.postMessage = async () => { throw new Error("slack down"); };
    deps.log = (line) => { logs.push(line); };
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await expect(drainAnalysisQueue(deps)).resolves.toBe(1);
    expect(logs.some((l) => l.includes("실패 알림 게시 실패"))).toBe(true);
  });
});
