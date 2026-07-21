import type { SpecPrRow } from "./db.js";

export type ReactionEvent = { user: string; reaction: string; item: { type: string; channel: string; ts: string } };

export type Route =
  | { kind: "trigger"; channel: string; ts: string; user: string }
  | { kind: "approve"; pr: SpecPrRow; user: string }
  | { kind: "reject"; pr: SpecPrRow; user: string }
  | { kind: "ignore" };

export type RouteDeps = {
  botUserId: string;
  channels: string[];
  specPrByMessage(channel: string, messageTs: string): SpecPrRow | null;
};

/** reaction_added 하나로 승인(✅/❌)과 분석 트리거(🤖)를 분기한다 (스펙 §4.1). */
export function routeReaction(ev: ReactionEvent, deps: RouteDeps): Route {
  if (ev.user === deps.botUserId || ev.item.type !== "message") return { kind: "ignore" };
  const pr = deps.specPrByMessage(ev.item.channel, ev.item.ts);
  if (pr) {
    // 승인 대기 답글에 달린 반응 — 🤖를 포함한 다른 이모지는 전부 무시해 봇 답글 재분석을 막는다
    if (pr.status !== "awaiting") return { kind: "ignore" };
    if (ev.reaction === "white_check_mark") return { kind: "approve", pr, user: ev.user };
    if (ev.reaction === "x") return { kind: "reject", pr, user: ev.user };
    return { kind: "ignore" };
  }
  if (ev.reaction === "robot_face" && deps.channels.includes(ev.item.channel))
    return { kind: "trigger", channel: ev.item.channel, ts: ev.item.ts, user: ev.user };
  return { kind: "ignore" };
}
