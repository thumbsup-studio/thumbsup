import { describe, expect, it } from "vitest";
import { applyEdits, buildEditPrompt, buildJudgePrompt } from "../src/analysis.js";

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
