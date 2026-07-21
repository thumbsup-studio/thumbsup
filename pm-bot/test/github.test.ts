import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
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

  it("commentIssue는 이슈 번호·repo·body로 댓글을 단다", async () => {
    const { exec, calls } = fakeExec([["gh issue comment", "https://github.com/o/r/issues/42#issuecomment-1\n"]]);
    expect(await createGhClient(CFG, exec).commentIssue({ number: 42, body: "b" })).toEqual({
      url: "https://github.com/o/r/issues/42#issuecomment-1",
    });
    expect(calls[0]).toBe("gh issue comment 42 --repo o/r --body b");
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

describe("createGhClient — .workrepo 명세 PR", () => {
  function workCfg() {
    const dir = mkdtempSync(join(tmpdir(), "workrepo-"));
    return { ...CFG, workRepoDir: join(dir, "repo") };
  }

  it("prepareSpecRepo는 .git이 없으면 blobless clone부터 한다", async () => {
    const cfg = workCfg();
    const { exec, calls } = fakeExec([["git clone", ""], ["git -C", ""]]);
    await createGhClient(cfg, exec).prepareSpecRepo();
    expect(calls[0]).toBe(`git clone --filter=blob:none https://github.com/o/r.git ${cfg.workRepoDir}`);
    expect(calls[1]).toContain("fetch origin");
    expect(calls[2]).toContain("checkout -f -B main origin/main");
    expect(calls[3]).toContain("clean -fd");
  });

  it("prepareSpecRepo는 clone이 있으면 fetch·리셋·클린만 한다", async () => {
    const cfg = workCfg();
    mkdirSync(join(cfg.workRepoDir, ".git"), { recursive: true });
    const { exec, calls } = fakeExec([["git -C", ""]]);
    await createGhClient(cfg, exec).prepareSpecRepo();
    expect(calls.some((c) => c.startsWith("git clone"))).toBe(false);
    expect(calls).toHaveLength(3);
    expect(calls[2]).toContain("clean -fd");
  });

  it("submitSpecPr는 브랜치·파일 쓰기·커밋·푸시·PR 생성을 순서대로 수행한다", async () => {
    const cfg = workCfg();
    mkdirSync(join(cfg.workRepoDir, "docs/superpowers/specs"), { recursive: true });
    const { exec, calls } = fakeExec([["git -C", ""], ["gh pr create", "https://github.com/o/r/pull/9\n"]]);
    const res = await createGhClient(cfg, exec).submitSpecPr({
      branch: "docs/pm-bot-1-0", files: [{ file: "spec.md", content: "새 내용" }],
      commitMsg: "docs(spec): x (pm-bot)", title: "docs(spec): x (pm-bot)", body: "근거",
    });
    expect(res).toEqual({ number: 9, url: "https://github.com/o/r/pull/9" });
    expect(readFileSync(join(cfg.workRepoDir, "docs/superpowers/specs/spec.md"), "utf8")).toBe("새 내용");
    const seq = calls.map((c) => c.split(" ").slice(0, 4).join(" "));
    expect(calls.some((c) => c.includes("checkout -B docs/pm-bot-1-0"))).toBe(true);
    expect(calls.some((c) => c.includes("commit -m"))).toBe(true);
    expect(calls.some((c) => c.includes("push -u origin docs/pm-bot-1-0 --force"))).toBe(true);
    expect(seq[seq.length - 1]).toContain("gh pr create");
  });

  it("readSpecFile은 specDirInRepo 밑에서 읽는다", async () => {
    const cfg = workCfg();
    mkdirSync(join(cfg.workRepoDir, "docs/superpowers/specs"), { recursive: true });
    writeFileSync(join(cfg.workRepoDir, "docs/superpowers/specs/a.md"), "본문", "utf8");
    const { exec } = fakeExec([]);
    expect(await createGhClient(cfg, exec).readSpecFile("a.md")).toBe("본문");
  });

  it("mergePr·closePr는 auto-squash·코멘트 클로즈를 호출한다", async () => {
    const { exec, calls } = fakeExec([["gh pr", ""]]);
    const gh = createGhClient(CFG, exec);
    await gh.mergePr(9);
    await gh.closePr(9, "반려");
    expect(calls[0]).toBe("gh pr merge 9 --repo o/r --auto --squash");
    expect(calls[1]).toBe("gh pr close 9 --repo o/r --comment 반려");
  });
});
