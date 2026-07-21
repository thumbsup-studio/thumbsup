import { describe, expect, it } from "vitest";
import type { SpecPrRow } from "../src/db.js";
import { routeReaction } from "../src/reactions.js";

const PR: SpecPrRow = { prNumber: 7, prUrl: "https://x/7", channel: "C1", messageTs: "9.0", threadTs: "1.0", status: "awaiting" };
const deps = (over: Partial<{ botUserId: string; channels: string[]; pr: SpecPrRow | null }> = {}) => ({
  botUserId: over.botUserId ?? "UBOT",
  channels: over.channels ?? ["C1"],
  specPrByMessage: (c: string, ts: string) => (c === "C1" && ts === "9.0" ? (over.pr === undefined ? PR : over.pr) : null),
});
const ev = (over: Partial<{ user: string; reaction: string; type: string; channel: string; ts: string }> = {}) => ({
  user: over.user ?? "U1",
  reaction: over.reaction ?? "robot_face",
  item: { type: over.type ?? "message", channel: over.channel ?? "C1", ts: over.ts ?? "1.0" },
});

describe("routeReaction", () => {
  it("감시 채널의 🤖는 trigger", () => {
    expect(routeReaction(ev(), deps())).toEqual({ kind: "trigger", channel: "C1", ts: "1.0", user: "U1" });
  });
  it("감시 밖 채널·다른 이모지·message 아닌 item·봇 자신은 ignore", () => {
    expect(routeReaction(ev({ channel: "C9" }), deps()).kind).toBe("ignore");
    expect(routeReaction(ev({ reaction: "eyes" }), deps()).kind).toBe("ignore");
    expect(routeReaction(ev({ type: "file" }), deps()).kind).toBe("ignore");
    expect(routeReaction(ev({ user: "UBOT" }), deps()).kind).toBe("ignore");
  });
  it("승인 대기 메시지의 ✅는 approve, ❌는 reject", () => {
    expect(routeReaction(ev({ reaction: "white_check_mark", ts: "9.0" }), deps())).toEqual({ kind: "approve", pr: PR, user: "U1" });
    expect(routeReaction(ev({ reaction: "x", ts: "9.0" }), deps())).toEqual({ kind: "reject", pr: PR, user: "U1" });
  });
  it("승인 대기 메시지의 🤖·기타 이모지는 ignore — 봇 답글 재분석 방지", () => {
    expect(routeReaction(ev({ reaction: "robot_face", ts: "9.0" }), deps()).kind).toBe("ignore");
    expect(routeReaction(ev({ reaction: "tada", ts: "9.0" }), deps()).kind).toBe("ignore");
  });
  it("이미 처리된(awaiting 아닌) PR 메시지의 ✅는 ignore", () => {
    expect(routeReaction(ev({ reaction: "white_check_mark", ts: "9.0" }), deps({ pr: { ...PR, status: "approved" } })).kind).toBe("ignore");
  });
});
