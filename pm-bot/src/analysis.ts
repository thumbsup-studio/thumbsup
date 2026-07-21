import type { SpecSection } from "./specindex.js";

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
