import { render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { RedirectIfAuthenticated } from "@/features/auth/redirect-if-authenticated";
import { getMyProfile, tokenStore } from "@/lib/api";

const { replaceMock } = vi.hoisted(() => ({ replaceMock: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ replace: replaceMock }) }));
vi.mock("@/lib/api", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api")>();
  return { ...actual, getMyProfile: vi.fn() };
});

const getMyProfileMock = vi.mocked(getMyProfile);

beforeEach(() => {
  vi.unstubAllEnvs();
  replaceMock.mockClear();
  getMyProfileMock.mockReset();
  localStorage.clear();
});

describe("RedirectIfAuthenticated", () => {
  it("로그인 상태(일반 유저)면 홈으로 replace하고 인증 화면을 렌더하지 않는다", async () => {
    tokenStore.set({ accessToken: "a", refreshToken: "r" });
    getMyProfileMock.mockResolvedValue({ email: "user@example.com", role: "USER" });

    render(
      <RedirectIfAuthenticated>
        <div>로그인 폼</div>
      </RedirectIfAuthenticated>,
    );

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/"));
    expect(screen.queryByText("로그인 폼")).not.toBeInTheDocument();
  });

  it("로그인 상태(ADMIN)면 저작 대시보드(/authoring)로 replace한다", async () => {
    tokenStore.set({ accessToken: "a", refreshToken: "r" });
    getMyProfileMock.mockResolvedValue({ email: "admin@thumbsup.local", role: "ADMIN" });

    render(
      <RedirectIfAuthenticated>
        <div>로그인 폼</div>
      </RedirectIfAuthenticated>,
    );

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/authoring"));
  });

  it("저작 앱 URL이 설정되면 로그인 상태의 ADMIN을 절대 URL로 보낸다", async () => {
    vi.stubEnv("NEXT_PUBLIC_AUTHORING_URL", "https://authoring.example.com");
    tokenStore.set({ accessToken: "a", refreshToken: "r" });
    getMyProfileMock.mockResolvedValue({ email: "admin@thumbsup.local", role: "ADMIN" });

    render(
      <RedirectIfAuthenticated>
        <div>로그인 폼</div>
      </RedirectIfAuthenticated>,
    );

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("https://authoring.example.com"));
  });

  it("토큰이 무효(role 조회 실패)면 인증 화면을 노출해 재로그인하게 한다", async () => {
    tokenStore.set({ accessToken: "a", refreshToken: "r" });
    getMyProfileMock.mockRejectedValue(new Error("invalid"));

    render(
      <RedirectIfAuthenticated>
        <div>로그인 폼</div>
      </RedirectIfAuthenticated>,
    );

    expect(await screen.findByText("로그인 폼")).toBeInTheDocument();
    expect(replaceMock).not.toHaveBeenCalled();
  });

  it("토큰이 없으면 인증 화면(children)을 렌더하고 리다이렉트하지 않는다", () => {
    render(
      <RedirectIfAuthenticated>
        <div>로그인 폼</div>
      </RedirectIfAuthenticated>,
    );

    expect(screen.getByText("로그인 폼")).toBeInTheDocument();
    expect(replaceMock).not.toHaveBeenCalled();
  });
});
