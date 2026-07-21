import { readFileSync } from "node:fs";

export type GithubConfig = { repo: string; projectOwner: string; projectNumber: number; specDirInRepo: string; account?: string };
export type PmConfig = {
  /** 수집 대상 Slack 채널 ID 목록 (스펙 §2 "지정 채널만") */
  channels: string[];
  dbPath: string;
  /** 명세 markdown 루트 (병합된 스프린트 문서) */
  specDir: string;
  claudeBin?: string;
  /** 없으면 GitHub 액션(명세 PR·이슈) 비활성 — 수집·Q&A만 동작 */
  github?: GithubConfig;
};

export function loadConfig(raw: unknown): PmConfig {
  if (typeof raw !== "object" || raw === null) throw new Error("설정은 JSON 객체여야 합니다.");
  const r = raw as Record<string, unknown>;
  const missing: string[] = [];
  if (!Array.isArray(r.channels) || r.channels.length === 0 || !r.channels.every((c) => typeof c === "string"))
    missing.push("channels(비어 있지 않은 문자열 배열)");
  if (typeof r.dbPath !== "string" || r.dbPath === "") missing.push("dbPath");
  if (typeof r.specDir !== "string" || r.specDir === "") missing.push("specDir");

  let github: GithubConfig | undefined;
  if (r.github !== undefined) {
    const g = r.github as Record<string, unknown>;
    if (typeof r.github !== "object" || r.github === null) missing.push("github(객체)");
    else if (typeof g.repo !== "string" || typeof g.projectOwner !== "string" || typeof g.projectNumber !== "number" || typeof g.specDirInRepo !== "string")
      missing.push("github.repo/projectOwner/projectNumber/specDirInRepo");
    else github = { repo: g.repo, projectOwner: g.projectOwner, projectNumber: g.projectNumber, specDirInRepo: g.specDirInRepo, account: typeof g.account === "string" ? g.account : undefined };
  }

  if (missing.length > 0) throw new Error(`pm-bot 설정 누락/오류: ${missing.join(", ")}`);
  return {
    channels: r.channels as string[],
    dbPath: r.dbPath as string,
    specDir: r.specDir as string,
    claudeBin: typeof r.claudeBin === "string" ? r.claudeBin : undefined,
    github,
  };
}

export function readConfigFile(path: string): PmConfig {
  return loadConfig(JSON.parse(readFileSync(path, "utf8")));
}
