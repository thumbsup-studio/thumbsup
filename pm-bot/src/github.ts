import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

export type Exec = (file: string, args: string[], opts?: { cwd?: string }) => Promise<{ stdout: string }>;
export type OpenIssue = { number: number; title: string; labels: string[] };
export type GhConfig = {
  repo: string;            // "thumbsup-studio/thumbsup"
  projectOwner: string;    // "thumbsup-studio" (org)
  projectNumber: number;   // Thumbs Up Roadmap = 2
  specDirInRepo: string;   // "docs/superpowers/specs"
  account?: string;        // 기대 gh 활성 계정 — 불일치 시 GitHub 액션 비활성 (403 함정)
  workRepoDir: string;     // 명세 PR용 blobless clone 절대 경로
};

type BoardMeta = {
  projectId: string;
  area: { fieldId: string; options: Record<string, string> };
  status: { fieldId: string; options: Record<string, string> };
};

const FIELDS_QUERY = `query($owner: String!, $number: Int!) {
  organization(login: $owner) { projectV2(number: $number) {
    id
    fields(first: 30) { nodes { ... on ProjectV2SingleSelectField { id name options { id name } } } }
  } }
}`;
const ADD_ITEM_MUTATION = `mutation($p: ID!, $c: ID!) { addProjectV2ItemById(input: { projectId: $p, contentId: $c }) { item { id } } }`;
const SET_FIELD_MUTATION = `mutation($p: ID!, $i: ID!, $f: ID!, $o: String!) {
  updateProjectV2ItemFieldValue(input: { projectId: $p, itemId: $i, fieldId: $f, value: { singleSelectOptionId: $o } }) { projectV2Item { id } }
}`;

export type GhClient = ReturnType<typeof createGhClient>;

export function createGhClient(cfg: GhConfig, exec: Exec) {
  let boardMeta: BoardMeta | null = null;

  async function gh(args: string[], opts?: { cwd?: string }): Promise<string> {
    return (await exec("gh", args, opts)).stdout.trim();
  }

  async function git(args: string[]): Promise<string> {
    return (await exec("git", ["-C", cfg.workRepoDir, ...args])).stdout.trim();
  }

  async function getBoardMeta(): Promise<BoardMeta> {
    if (boardMeta) return boardMeta;
    const raw = await gh(["api", "graphql", "-f", `query=${FIELDS_QUERY}`, "-f", `owner=${cfg.projectOwner}`, "-F", `number=${cfg.projectNumber}`]);
    const project = JSON.parse(raw).data.organization.projectV2 as {
      id: string;
      fields: { nodes: Array<{ id?: string; name?: string; options?: Array<{ id: string; name: string }> }> };
    };
    const pick = (name: string) => {
      const f = project.fields.nodes.find((n) => n.name === name);
      if (!f?.id || !f.options) throw new Error(`보드 필드 '${name}'를 찾을 수 없습니다`);
      return { fieldId: f.id, options: Object.fromEntries(f.options.map((o) => [o.name, o.id])) };
    };
    boardMeta = { projectId: project.id, area: pick("Area"), status: pick("Status") };
    return boardMeta;
  }

  async function setField(meta: BoardMeta, itemId: string, field: "area" | "status", value: string): Promise<void> {
    const optionId = meta[field].options[value];
    if (!optionId) throw new Error(`보드 ${field} 옵션 '${value}' 없음 — 가용: ${Object.keys(meta[field].options).join(", ")}`);
    await gh(["api", "graphql", "-f", `query=${SET_FIELD_MUTATION}`, "-f", `p=${meta.projectId}`, "-f", `i=${itemId}`, "-f", `f=${meta[field].fieldId}`, "-f", `o=${optionId}`]);
  }

  return {
    async checkAuth(): Promise<{ ok: boolean; login: string }> {
      const login = await gh(["api", "user", "-q", ".login"]);
      return { ok: !cfg.account || login === cfg.account, login };
    },

    async listOpenIssues(): Promise<OpenIssue[]> {
      const raw = await gh(["issue", "list", "--repo", cfg.repo, "--state", "open", "--limit", "200", "--json", "number,title,labels"]);
      return (JSON.parse(raw) as Array<{ number: number; title: string; labels: Array<{ name: string }> }>).map((i) => ({
        number: i.number, title: i.title, labels: i.labels.map((l) => l.name),
      }));
    },

    async createIssue(a: { title: string; body: string }): Promise<{ number: number; url: string }> {
      const url = await gh(["issue", "create", "--repo", cfg.repo, "--title", a.title, "--body", a.body]);
      const number = Number(url.split("/").pop());
      if (!Number.isInteger(number)) throw new Error(`이슈 URL 파싱 실패: ${url}`);
      return { number, url };
    },

    async commentIssue(a: { number: number; body: string }): Promise<{ url: string }> {
      return { url: await gh(["issue", "comment", String(a.number), "--repo", cfg.repo, "--body", a.body]) };
    },

    async boardOptions(): Promise<{ area: string[]; status: string[] }> {
      const meta = await getBoardMeta();
      return { area: Object.keys(meta.area.options), status: Object.keys(meta.status.options) };
    },

    /** 이슈를 보드에 넣고(이미 있으면 기존 아이템 재사용 — addProjectV2ItemById는 멱등) 필드를 설정한다. */
    async setBoardFields(issueNumber: number, fields: { area?: string; status?: string }): Promise<void> {
      const meta = await getBoardMeta();
      const nodeId = await gh(["api", `repos/${cfg.repo}/issues/${issueNumber}`, "-q", ".node_id"]);
      const added = await gh(["api", "graphql", "-f", `query=${ADD_ITEM_MUTATION}`, "-f", `p=${meta.projectId}`, "-f", `c=${nodeId}`]);
      const itemId = JSON.parse(added).data.addProjectV2ItemById.item.id as string;
      if (fields.area) await setField(meta, itemId, "area", fields.area);
      if (fields.status) await setField(meta, itemId, "status", fields.status);
    },

    /** 최초엔 blobless clone, 이후엔 fetch + origin/main 강제 리셋 — 잡 간 상태 오염 방지 (스펙 §4.4). */
    async prepareSpecRepo(): Promise<void> {
      if (!existsSync(join(cfg.workRepoDir, ".git"))) {
        await exec("git", ["clone", "--filter=blob:none", `https://github.com/${cfg.repo}.git`, cfg.workRepoDir]);
      }
      await git(["fetch", "origin"]);
      await git(["checkout", "-f", "-B", "main", "origin/main"]);
    },

    async readSpecFile(file: string): Promise<string> {
      return readFile(join(cfg.workRepoDir, cfg.specDirInRepo, file), "utf8");
    },

    async submitSpecPr(a: { branch: string; files: Array<{ file: string; content: string }>; commitMsg: string; title: string; body: string }): Promise<{ number: number; url: string }> {
      await git(["checkout", "-B", a.branch]);
      for (const f of a.files) {
        const path = join(cfg.workRepoDir, cfg.specDirInRepo, f.file);
        await mkdir(dirname(path), { recursive: true });
        await writeFile(path, f.content, "utf8");
      }
      await git(["add", "-A"]);
      await git(["commit", "-m", a.commitMsg]);
      await git(["push", "-u", "origin", a.branch, "--force"]); // 재분석 시 같은 브랜치 재사용
      const url = await gh(["pr", "create", "--repo", cfg.repo, "--head", a.branch, "--title", a.title, "--body", a.body], { cwd: cfg.workRepoDir });
      const number = Number(url.split("/").pop());
      if (!Number.isInteger(number)) throw new Error(`PR URL 파싱 실패: ${url}`);
      return { number, url };
    },

    async mergePr(prNumber: number): Promise<void> {
      await gh(["pr", "merge", String(prNumber), "--repo", cfg.repo, "--auto", "--squash"]);
    },

    async closePr(prNumber: number, comment: string): Promise<void> {
      await gh(["pr", "close", String(prNumber), "--repo", cfg.repo, "--comment", comment]);
    },
  };
}
