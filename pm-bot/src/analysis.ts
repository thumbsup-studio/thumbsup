import { runWithRetry } from "./adapters/claude.js";
import type { CliAdapter } from "./adapters/types.js";
import type { HistoryClient } from "./collector.js";
import type { PmDb } from "./db.js";
import type { GhClient } from "./github.js";
import { search, type SpecSection } from "./specindex.js";

export const ANALYSIS_SYSTEM_PROMPT =
  "너는 떰즈업 팀의 PM 어시스턴트다. 요청받은 JSON만 출력한다. 제공된 스레드와 명세 발췌만 근거로 판단하고, 근거가 약하면 항목을 만들지 않는다.";

export type ThreadMsg = { user: string; text: string };
export type SpecChange = { file: string; summary: string; rationale: string; edit_instruction: string };
export type IssueAction = { kind: "create" | "update"; number?: number; title: string; body: string; area: string; status: string };
export type JudgeResult = { spec_changes: SpecChange[]; issue_actions: IssueAction[]; nothing_found: boolean };
export type PrevResult = { prUrl?: string; issueUrls: string[] };

export function buildJudgePrompt(args: {
  thread: ThreadMsg[];
  permalink: string;
  hits: SpecSection[];
  openIssues: Array<{ number: number; title: string; labels: string[] }>;
  areaOptions: string[];
  statusOptions: string[];
  prev?: PrevResult;
}): { prompt: string; outputSchema: object } {
  const thread = args.thread.map((m) => `${m.user}: ${m.text}`).join("\n");
  const specs = args.hits.map((h) => `### ${h.file} — ${h.heading}\n${h.body}`).join("\n\n") || "(검색 결과 없음)";
  const issues = args.openIssues.map((i) => `#${i.number} ${i.title} [${i.labels.join(",")}]`).join("\n") || "(없음)";
  const prevNote = args.prev
    ? `\n\n## 이전 처리 결과 (중복 금지)\n이 스레드는 전에 분석되어 아래가 이미 등록됐다. 같은 내용의 이슈를 새로 만들지 말고, 달라진 부분만 기존 이슈 update나 새 항목으로 판정하라.\n${[args.prev.prUrl && `- 명세 PR: ${args.prev.prUrl}`, ...args.prev.issueUrls.map((u) => `- 이슈: ${u}`)].filter(Boolean).join("\n")}`
    : "";
  const prompt = `Slack 스레드를 분석해 (1) 명세 수정 필요 항목과 (2) GitHub 이슈로 만들거나 갱신할 항목을 판정하라.
합의되지 않은 아이디어 나열·단순 정보 공유는 아무것도 만들지 않는다(nothing_found=true).

## 스레드 (링크: ${args.permalink})
${thread}

## 관련 명세 발췌 (spec_changes.file은 반드시 이 파일명 중에서만)
${specs}

## 현재 열린 이슈 (중복이면 kind=update + number)
${issues}${prevNote}

## 지시
- spec_changes.edit_instruction: 편집자가 파일을 열고 그대로 수행할 수 있게 어느 부분을 어떻게 바꿀지 구체적으로
- issue_actions.title: "feat(app): …" 형식의 한국어 요약, body: 배경·할 일·근거 스레드 링크(${args.permalink}) 포함
- area·status는 제시된 옵션값 중에서만 선택`;
  return {
    prompt,
    outputSchema: {
      type: "object",
      properties: {
        spec_changes: {
          type: "array",
          items: {
            type: "object",
            properties: {
              file: { type: "string" }, summary: { type: "string" },
              rationale: { type: "string" }, edit_instruction: { type: "string" },
            },
            required: ["file", "summary", "rationale", "edit_instruction"],
            additionalProperties: false,
          },
        },
        issue_actions: {
          type: "array",
          items: {
            type: "object",
            properties: {
              kind: { enum: ["create", "update"] }, number: { type: "integer" },
              title: { type: "string" }, body: { type: "string" },
              area: { enum: args.areaOptions }, status: { enum: args.statusOptions },
            },
            required: ["kind", "title", "body", "area", "status"],
            additionalProperties: false,
          },
        },
        nothing_found: { type: "boolean" },
      },
      required: ["spec_changes", "issue_actions", "nothing_found"],
      additionalProperties: false,
    },
  };
}

export function buildEditPrompt(args: { file: string; content: string; instruction: string }): { prompt: string; outputSchema: object } {
  return {
    prompt: `아래 markdown 파일에 편집 지시를 적용하기 위한 문자열 치환 목록을 만들어라.
old는 파일에서 정확히 1번만 등장하는 원문 그대로(공백·개행 포함), new는 치환 결과다.

## 파일: ${args.file}
${args.content}

## 편집 지시
${args.instruction}`,
    outputSchema: {
      type: "object",
      properties: {
        edits: {
          type: "array", minItems: 1,
          items: {
            type: "object",
            properties: { old: { type: "string" }, new: { type: "string" } },
            required: ["old", "new"],
            additionalProperties: false,
          },
        },
      },
      required: ["edits"],
      additionalProperties: false,
    },
  };
}

/** 치환을 결정적으로 적용한다. 매치가 정확히 1건이 아니면 throw (스펙 §4.3). */
export function applyEdits(content: string, edits: Array<{ old: string; new: string }>): string {
  let out = content;
  edits.forEach((e, i) => {
    const count = out.split(e.old).length - 1;
    if (count !== 1) throw new Error(`edits[${i}]: old 문자열 매치 ${count}건 (정확히 1건이어야 함)`);
    out = out.replace(e.old, e.new);
  });
  return out;
}

export type FetchedThread = { msgs: ThreadMsg[]; lastMsgTs: string };

/** 스레드 전문을 실시간 조회한다. user 없는 봇 메시지(허들 AI 노트)도 포함 — 스펙 §2. */
export async function fetchThread(client: HistoryClient, channel: string, threadTs: string): Promise<FetchedThread> {
  const msgs: ThreadMsg[] = [];
  let lastMsgTs = threadTs;
  let cursor: string | undefined;
  do {
    const page = await client.replies({ channel, ts: threadTs, cursor });
    for (const m of page.messages) {
      if (!m.text) continue;
      msgs.push({ user: m.user ?? "bot", text: m.text });
      if (Number(m.ts) > Number(lastMsgTs)) lastMsgTs = m.ts;
    }
    cursor = page.nextCursor;
  } while (cursor);
  return { msgs, lastMsgTs };
}

export type AnalysisDeps = {
  db: PmDb;
  adapter: CliAdapter;
  index: SpecSection[];
  gh: GhClient | null;
  history: HistoryClient;
  getPermalink(channel: string, ts: string): Promise<string>;
  postMessage(channel: string, threadTs: string, text: string): Promise<{ ts: string }>;
  log(line: string): void;
};

function prevLinks(prev: PrevResult): string {
  return [prev.prUrl && `\n• 명세 PR: ${prev.prUrl}`, ...prev.issueUrls.map((u) => `\n• 이슈: ${u}`)].filter(Boolean).join("");
}

/** issueUrls 중복 없이 직렬화 — 성공·부분 실패 저장 공통 (스펙 §6: 이전 결과 보존). */
function serializeResult(result: PrevResult): string {
  return JSON.stringify({ prUrl: result.prUrl, issueUrls: [...new Set(result.issueUrls)] });
}

/** pending 분석을 순차 처리한다. 실패는 failed로 남기고 스레드에 알린다 (조용한 실패 금지). */
export async function drainAnalysisQueue(deps: AnalysisDeps): Promise<number> {
  let handled = 0;
  for (let job = deps.db.nextPendingAnalysis(); job !== null; job = deps.db.nextPendingAnalysis()) {
    deps.db.markAnalysisRunning(job.channel, job.threadTs);
    const done: string[] = []; // 부분 성공 추적 — catch에서 보고·result_json 병합에 포함
    const result: PrevResult = { issueUrls: [] };
    const prev: PrevResult | undefined = job.resultJson ? (JSON.parse(job.resultJson) as PrevResult) : undefined;
    if (prev) {
      // 이번 런 실패해도 이전에 성공한 PR·이슈 링크를 잃지 않도록 결과를 prev로 시드한다.
      result.prUrl = prev.prUrl;
      result.issueUrls.push(...prev.issueUrls);
    }
    try {
      if (!deps.gh) throw new Error("GitHub 연동 비활성 상태예요 (gh 계정·config.github 확인)");
      const gh = deps.gh;
      const { msgs, lastMsgTs } = await fetchThread(deps.history, job.channel, job.threadTs);
      if (prev && job.lastMsgTs === lastMsgTs) {
        await deps.postMessage(job.channel, job.threadTs, `🤖 이미 처리한 스레드예요 (새 메시지 없음).${prevLinks(prev)}`);
        deps.db.markAnalysisDone(job.channel, job.threadTs, lastMsgTs, job.resultJson!);
        handled += 1;
        continue;
      }
      const permalink = await deps.getPermalink(job.channel, job.threadTs);
      const options = await gh.boardOptions();
      const openIssues = await gh.listOpenIssues();
      const hits = search(deps.index, msgs.map((m) => m.text).join(" ").slice(0, 2000));
      const judgeRaw = await runWithRetry(deps.adapter, buildJudgePrompt({ thread: msgs, permalink, hits, openIssues, areaOptions: options.area, statusOptions: options.status, prev }), { onLog: deps.log });
      const judge = JSON.parse(judgeRaw) as JudgeResult;

      if (judge.spec_changes.length > 0) {
        await gh.prepareSpecRepo();
        const files: Array<{ file: string; content: string }> = [];
        for (const c of judge.spec_changes) {
          if (c.file.includes("/") || c.file.includes("\\") || c.file.includes(".."))
            throw new Error(`spec_changes.file에 경로 문자 불허: ${c.file}`);
          const content = await gh.readSpecFile(c.file);
          const editRaw = await runWithRetry(deps.adapter, buildEditPrompt({ file: c.file, content, instruction: c.edit_instruction }), { onLog: deps.log });
          files.push({ file: c.file, content: applyEdits(content, (JSON.parse(editRaw) as { edits: Array<{ old: string; new: string }> }).edits) });
        }
        const summary = judge.spec_changes.map((c) => c.summary).join(", ");
        // 재분석마다 브랜치가 고유해야 함 — 스레드 고정 브랜치면 이전 PR이 열려 있을 때 gh pr create가
        // "already exists"로 실패하거나, force-push가 이미 승인된 PR 내용을 소리 없이 바꿔버린다.
        const branch = `docs/pm-bot-${job.threadTs.replace(".", "-")}-${lastMsgTs.replace(".", "-")}`;
        const stale = deps.db.awaitingSpecPrsByThread(job.channel, job.threadTs);
        for (const s of stale) {
          await gh.closePr(s.prNumber, "PM봇: 재분석으로 대체됨 (superseded)");
          deps.db.markSpecPr(s.prNumber, "superseded");
        }
        const pr = await gh.submitSpecPr({
          branch,
          files,
          commitMsg: `docs(spec): ${summary} (pm-bot)`,
          title: `docs(spec): ${summary} (pm-bot)`,
          body: `근거 스레드: ${permalink}\n\n${judge.spec_changes.map((c) => `- ${c.summary}: ${c.rationale}`).join("\n")}`,
        });
        result.prUrl = pr.url;
        done.push(`명세 PR: ${pr.url}`);
        const supersedeNote = stale.map((s) => `\n(이전 제안 ${s.prUrl}은 대체되어 닫혔어요)`).join("");
        const posted = await deps.postMessage(job.channel, job.threadTs, `📝 명세 변경 제안: ${pr.url}\n이 메시지에 ✅ 반응 → 자동 머지, ❌ → 반려${supersedeNote}`);
        deps.db.insertSpecPr({ prNumber: pr.number, prUrl: pr.url, channel: job.channel, messageTs: posted.ts, threadTs: job.threadTs, status: "awaiting" });
      }

      for (const a of judge.issue_actions) {
        if (a.kind === "create") {
          const issue = await gh.createIssue({ title: a.title, body: `${a.body}\n\n근거 스레드: ${permalink}` });
          await gh.setBoardFields(issue.number, { area: a.area, status: a.status });
          result.issueUrls.push(issue.url);
          done.push(`이슈 생성: ${issue.url}`);
        } else {
          if (a.number == null) throw new Error(`issue_actions update에 number 없음: ${a.title}`);
          const c = await gh.commentIssue({ number: a.number, body: `${a.body}\n\n근거 스레드: ${permalink}` });
          await gh.setBoardFields(a.number, { status: a.status });
          result.issueUrls.push(c.url);
          done.push(`이슈 갱신: #${a.number}`);
        }
      }

      if (done.length === 0) {
        await deps.postMessage(job.channel, job.threadTs, "🤖 분석했지만 명세 변경·이슈로 등록할 내용을 찾지 못했어요.");
      } else {
        await deps.postMessage(job.channel, job.threadTs, `🤖 분석 완료:\n${done.map((d) => `• ${d}`).join("\n")}`);
      }
      deps.db.markAnalysisDone(job.channel, job.threadTs, lastMsgTs, serializeResult(result));
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      // result는 이미 prev로 시드돼 있으므로, 이번 런에 새 진행(done)이 있을 때만 갱신 — 없으면 null로 COALESCE 보존.
      const partialResult = done.length > 0 ? serializeResult(result) : null;
      deps.db.markAnalysisFailed(job.channel, job.threadTs, msg, partialResult);
      const partial = done.length > 0 ? `\n완료된 항목:\n${done.map((d) => `• ${d}`).join("\n")}` : "";
      try {
        await deps.postMessage(job.channel, job.threadTs, `⚠️ 분석 처리에 실패했어요: ${msg}${partial}\n🤖를 다시 달면 재시도해요.`);
      } catch (postErr) {
        deps.log(`실패 알림 게시 실패 (${job.channel}/${job.threadTs}): ${postErr instanceof Error ? postErr.message : String(postErr)}`);
      }
    }
    handled += 1;
  }
  return handled;
}
