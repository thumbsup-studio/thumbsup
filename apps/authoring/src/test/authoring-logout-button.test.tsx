import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { LogoutButton } from "@/features/auth/logout-button";
import { logout } from "@/lib/api";

const { refreshMock, replaceMock } = vi.hoisted(() => ({
  refreshMock: vi.fn(),
  replaceMock: vi.fn(),
}));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ refresh: refreshMock, replace: replaceMock }),
}));
vi.mock("@/lib/api", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api")>();
  return { ...actual, logout: vi.fn() };
});

const logoutMock = vi.mocked(logout);

beforeEach(() => {
  logoutMock.mockReset();
  refreshMock.mockReset();
  replaceMock.mockReset();
});

describe("LogoutButton", () => {
  it("서버와 로컬 세션을 정리하고 로그인 화면으로 이동한다", async () => {
    logoutMock.mockResolvedValue();
    render(<LogoutButton />);

    fireEvent.click(screen.getByRole("button", { name: "로그아웃" }));

    await waitFor(() => expect(logoutMock).toHaveBeenCalledOnce());
    expect(replaceMock).toHaveBeenCalledWith("/login");
    expect(refreshMock).toHaveBeenCalledOnce();
  });
});
