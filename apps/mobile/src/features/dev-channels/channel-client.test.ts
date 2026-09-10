import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { channelIndexUrl, parseChannelIndex } from "./channel-client";

describe("PR 채널 목록", () => {
  beforeEach(() => {
    process.env.EXPO_PUBLIC_UPDATES_URL = "https://updates.example.com/api/manifest";
  });

  afterEach(() => {
    delete process.env.EXPO_PUBLIC_UPDATES_URL;
  });

  it("고정된 업데이트 URL에서 인덱스 경로를 만든다", () => {
    expect(channelIndexUrl()).toBe("https://updates.example.com/channels/index.json");
  });

  it("Android 에뮬레이터의 로컬 HTTP 업데이트 서버를 허용한다", () => {
    process.env.EXPO_PUBLIC_UPDATES_URL = "http://10.0.2.2:8081";
    expect(channelIndexUrl()).toBe("http://10.0.2.2:8081/channels/index.json");
  });

  it("PR 채널의 최신 업데이트 메타데이터를 생성 시각 순으로 읽는다", () => {
    expect(
      parseChannelIndex({
        channels: {
          staging: [],
          "pr-349": [
            {
              updateId: "id-349",
              runtimeVersion: "0.1.0",
              createdAt: "2026-09-08T02:00:00.000Z",
              prNumber: 349,
              title: "채널 선택기",
              branch: "feat/349-mobile-channel-picker",
              commit: "abcdef123456",
            },
          ],
          "pr-348": [
            {
              updateId: "id-348",
              runtimeVersion: "0.1.0",
              createdAt: "2026-09-08T01:00:00.000Z",
              prNumber: 348,
              title: "배포 파이프라인",
              branch: "feat/348-pr-bundle-publish",
              commit: "123456abcdef",
            },
          ],
        },
      }).map((channel) => channel.prNumber),
    ).toEqual([349, 348]);
  });
});
