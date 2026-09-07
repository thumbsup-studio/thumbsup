import { render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { RequireAdmin } from "@/features/auth/require-admin";
import { ApiError, getMyProfile } from "@/lib/api";

const { replaceMock } = vi.hoisted(() => ({
  replaceMock: vi.fn(),
}));

vi.mock("next/navigation", () => ({ useRouter: () => ({ replace: replaceMock }) }));
vi.mock("@/lib/api", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api")>();
  return { ...actual, getMyProfile: vi.fn() };
});

const getMyProfileMock = vi.mocked(getMyProfile);

beforeEach(() => {
  replaceMock.mockClear();
  getMyProfileMock.mockReset();
});

describe("RequireAdmin", () => {
  it("role이 ADMIN이면 보호 콘텐츠를 렌더하고 리다이렉트하지 않는다", async () => {
    getMyProfileMock.mockResolvedValue({ email: "admin@example.com", role: "ADMIN" });

    render(
      <RequireAdmin>
        <div>저작 대시보드</div>
      </RequireAdmin>,
    );

    expect(await screen.findByText("저작 대시보드")).toBeInTheDocument();
    expect(replaceMock).not.toHaveBeenCalled();
  });

  it("role이 USER면 홈으로 리다이렉트하고 보호 콘텐츠를 렌더하지 않는다", async () => {
    getMyProfileMock.mockResolvedValue({ email: "user@example.com", role: "USER" });

    render(
      <RequireAdmin>
        <div>저작 대시보드</div>
      </RequireAdmin>,
    );

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/"));
    expect(screen.queryByText("저작 대시보드")).not.toBeInTheDocument();
  });

  it("세션 만료(401)면 로그인 화면으로 이동한다", async () => {
    getMyProfileMock.mockRejectedValue(
      new ApiError({ code: "UNAUTHORIZED", status: 401, message: "unauthorized" }),
    );

    render(
      <RequireAdmin>
        <div>저작 대시보드</div>
      </RequireAdmin>,
    );

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/login"));
    expect(screen.queryByText("저작 대시보드")).not.toBeInTheDocument();
  });
});
