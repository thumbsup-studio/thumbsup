import { describe, expect, it } from "vitest";
import { createGhClient, type Exec } from "../src/github.js";

const CFG = { repo: "o/r", projectOwner: "o", projectNumber: 2, specDirInRepo: "docs/superpowers/specs", account: "kmjnnhyk", workRepoDir: "/tmp/none" };

/** 명령 프리픽스 → stdout 응답을 등록하고 호출 기록을 남기는 가짜 exec */
function fakeExec(responses: Array<[string, string]>) {
  const calls: string[] = [];
  const exec: Exec = async (file, args) => {
    const cmd = [file, ...args].join(" ");
    calls.push(cmd);
    const hit = responses.find(([prefix]) => cmd.startsWith(prefix));
    if (!hit) throw new Error(`unexpected: ${cmd}`);
    return { stdout: hit[1] };
  };
  return { exec, calls };
}

const BOARD_META = JSON.stringify({
  data: { organization: { projectV2: { id: "P1", fields: { nodes: [
    { id: "F_ST", name: "Status", options: [{ id: "o1", name: "Todo" }, { id: "o2", name: "Done" }] },
    { id: "F_AR", name: "Area", options: [{ id: "a1", name: "S2 홈" }] },
    {},
  ] } } } },
});

describe("createGhClient — 인증·이슈·보드", () => {
  it("checkAuth는 활성 계정이 account와 일치할 때만 ok", async () => {
    const { exec } = fakeExec([["gh api user", "kmjnnhyk\n"]]);
    expect(await createGhClient(CFG, exec).checkAuth()).toEqual({ ok: true, login: "kmjnnhyk" });
    const { exec: e2 } = fakeExec([["gh api user", "jinhyeok-bell\n"]]);
    expect(await createGhClient(CFG, e2).checkAuth()).toEqual({ ok: false, login: "jinhyeok-bell" });
  });

  it("listOpenIssues는 gh issue list JSON을 파싱한다", async () => {
    const { exec, calls } = fakeExec([["gh issue list", JSON.stringify([{ number: 3, title: "t", labels: [{ name: "app" }] }])]]);
    expect(await createGhClient(CFG, exec).listOpenIssues()).toEqual([{ number: 3, title: "t", labels: ["app"] }]);
    expect(calls[0]).toContain("--repo o/r");
    expect(calls[0]).toContain("--state open");
  });

  it("createIssue는 URL에서 번호를 파싱한다", async () => {
    const { exec } = fakeExec([["gh issue create", "https://github.com/o/r/issues/42\n"]]);
    expect(await createGhClient(CFG, exec).createIssue({ title: "t", body: "b" })).toEqual({ number: 42, url: "https://github.com/o/r/issues/42" });
  });

  it("setBoardFields는 아이템 추가 후 필드 2개를 설정한다", async () => {
    const { exec, calls } = fakeExec([
      ["gh api graphql -f query=query", BOARD_META],
      ["gh api repos/o/r/issues/42", "I_node\n"],
      ["gh api graphql -f query=mutation($p: ID!, $c: ID!)", JSON.stringify({ data: { addProjectV2ItemById: { item: { id: "ITEM1" } } } })],
      ["gh api graphql -f query=mutation($p: ID!, $i: ID!", "{}"],
    ]);
    await createGhClient(CFG, exec).setBoardFields(42, { area: "S2 홈", status: "Todo" });
    const mutations = calls.filter((c) => c.includes("updateProjectV2ItemFieldValue"));
    expect(mutations).toHaveLength(2);
    expect(mutations[0]).toContain("a1");
    expect(mutations[1]).toContain("o1");
  });

  it("모르는 area 옵션이면 가용 옵션을 담아 throw", async () => {
    const { exec } = fakeExec([
      ["gh api graphql -f query=query", BOARD_META],
      ["gh api repos/o/r/issues/42", "I_node\n"],
      ["gh api graphql -f query=mutation($p: ID!, $c: ID!)", JSON.stringify({ data: { addProjectV2ItemById: { item: { id: "ITEM1" } } } })],
    ]);
    await expect(createGhClient(CFG, exec).setBoardFields(42, { area: "없는곳" })).rejects.toThrow(/S2 홈/);
  });

  it("boardOptions는 옵션 이름 목록을 준다 (조회는 1회 캐시)", async () => {
    const { exec, calls } = fakeExec([["gh api graphql -f query=query", BOARD_META]]);
    const gh = createGhClient(CFG, exec);
    expect(await gh.boardOptions()).toEqual({ area: ["S2 홈"], status: ["Todo", "Done"] });
    await gh.boardOptions();
    expect(calls).toHaveLength(1);
  });
});
