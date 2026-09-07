import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthoringLoginForm } from "@/features/auth/authoring-login-form";
import { getMyProfile, login, tokenStore } from "@/lib/api";

const { replaceMock } = vi.hoisted(() => ({ replaceMock: vi.fn() }));

vi.mock("next/navigation", () => ({ useRouter: () => ({ replace: replaceMock }) }));
vi.mock("@/lib/api", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api")>();
  return { ...actual, getMyProfile: vi.fn(), login: vi.fn() };
});

const loginMock = vi.mocked(login);
const getMyProfileMock = vi.mocked(getMyProfile);

function submitLogin() {
  fireEvent.change(screen.getByLabelText("이메일"), {
    target: { value: "admin@thumbsup.local" },
  });
  fireEvent.change(screen.getByLabelText("비밀번호"), { target: { value: "admin1234" } });
  fireEvent.click(screen.getByRole("button", { name: "로그인" }));
}

beforeEach(() => {
  localStorage.clear();
  replaceMock.mockReset();
  loginMock.mockReset();
  getMyProfileMock.mockReset();
});

describe("AuthoringLoginForm", () => {
  it("ADMIN 로그인 성공 시 저작 앱 홈으로 이동한다", async () => {
    loginMock.mockResolvedValue({ accessToken: "a", refreshToken: "r" });
    getMyProfileMock.mockResolvedValue({ email: "admin@thumbsup.local", role: "ADMIN" });

    render(<AuthoringLoginForm />);
    submitLogin();

    await waitFor(() => expect(replaceMock).toHaveBeenCalledWith("/"));
  });

  it("일반 사용자는 저장된 토큰을 지우고 관리자 전용 안내를 표시한다", async () => {
    tokenStore.set({ accessToken: "a", refreshToken: "r" });
    loginMock.mockResolvedValue({ accessToken: "a", refreshToken: "r" });
    getMyProfileMock.mockResolvedValue({ email: "user@example.com", role: "USER" });

    render(<AuthoringLoginForm />);
    submitLogin();

    expect(await screen.findByText(/관리자 계정만/)).toBeInTheDocument();
    expect(tokenStore.get()).toBeNull();
    expect(replaceMock).not.toHaveBeenCalled();
  });
});
