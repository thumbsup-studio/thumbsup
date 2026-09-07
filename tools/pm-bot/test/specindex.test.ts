import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { buildIndex, search } from "../src/specindex.js";

function specDir(): string {
  const dir = mkdtempSync(join(tmpdir(), "spec-"));
  writeFileSync(
    join(dir, "14_priority.md"),
    "# 우선순위\n\n## 2순위\n\n- F-45 북마크: 히스토리 탭에서 문제 보관 (#36)\n\n## 3순위\n\n- F-17 Codex 정리장\n",
  );
  writeFileSync(join(dir, "10_features.md"), "# 기능\n\n## 저장 계열\n\nF-45는 북마크 기능이다. PG-08 참고.\n");
  return dir;
}

describe("buildIndex", () => {
  it("헤딩 단위로 나누고 ID를 추출한다", () => {
    const index = buildIndex(specDir());
    const sec = index.find((s) => s.heading === "2순위");
    expect(sec?.ids).toContain("F-45");
    expect(sec?.ids).toContain("#36");
  });
});

describe("search", () => {
  it("질문 속 ID가 있으면 해당 섹션이 최상위", () => {
    const index = buildIndex(specDir());
    const hits = search(index, "F-45 스펙이 뭐야?");
    expect(hits.length).toBeGreaterThanOrEqual(2);
    expect(hits[0]!.ids).toContain("F-45");
  });

  it("ID가 없으면 키워드 겹침으로 찾는다", () => {
    const index = buildIndex(specDir());
    expect(search(index, "북마크 어떻게 되지")[0]!.body).toContain("북마크");
  });
});
