import { describe, expect, it } from "vitest";
import { getAuthoringRedirects } from "../../next.config";

describe("authoring redirects", () => {
  it("저작 앱 URL이 없으면 이전 경로를 리다이렉트하지 않는다", () => {
    expect(getAuthoringRedirects(undefined)).toEqual([]);
  });

  it("이전 저작 경로와 하위 경로를 새 origin으로 임시 리다이렉트한다", () => {
    expect(getAuthoringRedirects("https://thumbsup-authoring.vercel.app/")).toEqual([
      {
        source: "/authoring",
        destination: "https://thumbsup-authoring.vercel.app",
        permanent: false,
      },
      {
        source: "/authoring/:path*",
        destination: "https://thumbsup-authoring.vercel.app/:path*",
        permanent: false,
      },
    ]);
  });
});
