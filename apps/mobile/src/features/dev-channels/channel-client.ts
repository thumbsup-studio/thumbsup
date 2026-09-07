export interface PrChannel {
  prNumber: number;
  title: string;
  branch: string;
  commit: string;
  createdAt: string;
  runtimeVersion: string;
}

interface ChannelIndexEntry {
  type?: "update" | "rollback";
  prNumber?: number;
  title?: string;
  branch?: string;
  commit?: string;
  createdAt?: string;
  runtimeVersion?: string;
}

interface ChannelIndex {
  channels?: Record<string, ChannelIndexEntry[]>;
}

function parsePrNumber(channel: string, entry: ChannelIndexEntry): number | null {
  if (Number.isSafeInteger(entry.prNumber) && (entry.prNumber ?? 0) > 0)
    return entry.prNumber ?? null;
  const match = /^pr-(\d+)$/.exec(channel);
  return match ? Number(match[1]) : null;
}

export function parseChannelIndex(value: unknown): PrChannel[] {
  if (!value || typeof value !== "object") throw new Error("채널 목록 형식이 올바르지 않습니다.");
  const { channels } = value as ChannelIndex;
  if (!channels || typeof channels !== "object") throw new Error("채널 목록이 없습니다.");

  const result: PrChannel[] = [];
  for (const [channel, entries] of Object.entries(channels)) {
    if (!/^pr-\d+$/.test(channel) || !Array.isArray(entries)) continue;
    const entry = entries.find((candidate) => candidate.type !== "rollback");
    if (!entry) continue;
    const prNumber = parsePrNumber(channel, entry);
    if (
      prNumber === null ||
      typeof entry.title !== "string" ||
      typeof entry.branch !== "string" ||
      typeof entry.commit !== "string" ||
      typeof entry.createdAt !== "string" ||
      typeof entry.runtimeVersion !== "string"
    ) {
      continue;
    }
    result.push({
      prNumber,
      title: entry.title,
      branch: entry.branch,
      commit: entry.commit,
      createdAt: entry.createdAt,
      runtimeVersion: entry.runtimeVersion,
    });
  }
  return result.sort((left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt));
}

export function channelIndexUrl(): string {
  const configuredUrl = process.env.EXPO_PUBLIC_UPDATES_URL;
  if (!configuredUrl) {
    throw new Error("업데이트 서버가 설정되지 않았습니다.");
  }
  const url = new URL(configuredUrl);
  const localHttp =
    url.protocol === "http:" && ["10.0.2.2", "127.0.0.1", "localhost"].includes(url.hostname);
  if (url.protocol !== "https:" && !localHttp) {
    throw new Error("업데이트 서버가 설정되지 않았습니다.");
  }
  return `${url.origin}/channels/index.json`;
}

export async function fetchPrChannels(signal?: AbortSignal): Promise<PrChannel[]> {
  const response = await fetch(channelIndexUrl(), {
    headers: { Accept: "application/json" },
    signal,
  });
  if (!response.ok) throw new Error(`채널 목록 요청 실패 (${response.status})`);
  return parseChannelIndex(await response.json());
}
