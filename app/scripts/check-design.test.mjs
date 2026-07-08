import { test } from "node:test";
import assert from "node:assert/strict";
import { findStyleViolations, findMissingStories } from "./check-design.mjs";

test("raw hex와 arbitrary value를 검출한다", () => {
  const v = findStyleViolations('<div className="bg-[#2f63ff] rounded-[36px]" />', "a.tsx");
  assert.ok(v.some((x) => x.kind === "arbitrary-value"), "arbitrary 검출");
  assert.ok(v.some((x) => x.kind === "raw-hex"), "hex 검출");
});

test("design-ok 주석이 있는 줄은 예외", () => {
  const v = findStyleViolations('const brand = "#2f63ff"; // design-ok', "a.tsx");
  assert.equal(v.length, 0);
});

test("토큰 유틸리티는 통과", () => {
  const v = findStyleViolations('<div className="bg-primary rounded-card text-ink" />', "a.tsx");
  assert.equal(v.length, 0);
});

test("스토리 없는 컴포넌트를 찾는다", () => {
  const missing = findMissingStories(["button.tsx", "card.tsx", "card.stories.tsx", "index.ts"]);
  assert.deepEqual(missing.map((m) => m.component), ["button.tsx"]);
});
