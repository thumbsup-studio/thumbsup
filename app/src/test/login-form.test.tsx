import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { LoginForm } from "@/features/auth/login-form";
import { ApiError, login } from "@/lib/api";

const { pushMock } = vi.hoisted(() => ({ pushMock: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));
vi.mock("@/lib/api", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api")>();
  return { ...actual, login: vi.fn() };
});

const loginMock = vi.mocked(login);

function fillForm(email: string, password: string) {
  fireEvent.change(screen.getByLabelText("이메일"), { target: { value: email } });
  fireEvent.change(screen.getByLabelText("비밀번호"), { target: { value: password } });
}

beforeEach(() => {
  pushMock.mockClear();
  loginMock.mockReset();
});

describe("LoginForm", () => {
  it("로그인 성공 시 입력값으로 login을 호출하고 홈으로 이동한다", async () => {
    loginMock.mockResolvedValue({ accessToken: "a", refreshToken: "r" });
    render(<LoginForm />);

    fillForm("user@example.com", "password123");
    fireEvent.click(screen.getByRole("button", { name: "로그인" }));

    await waitFor(() => expect(pushMock).toHaveBeenCalledWith("/"));
    expect(loginMock).toHaveBeenCalledWith("user@example.com", "password123");
  });

  it("로그인 실패 시 통합 에러 피드백과 비밀번호 에러 상태, '다시 로그인' 버튼을 노출한다", async () => {
    loginMock.mockRejectedValue(
      new ApiError({ code: "INVALID_CREDENTIALS", status: 401, message: "실패" }),
    );
    render(<LoginForm />);

    fillForm("user@example.com", "wrong-password");
    fireEvent.click(screen.getByRole("button", { name: "로그인" }));

    expect(await screen.findByText("로그인에 실패했어요")).toBeInTheDocument();
    expect(screen.getByLabelText("비밀번호")).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByRole("button", { name: /다시 로그인/ })).toBeInTheDocument();
    expect(pushMock).not.toHaveBeenCalled();
  });

  it("형식 오류면 API를 호출하지 않고 통합 에러만 보여준다", async () => {
    render(<LoginForm />);

    fillForm("not-an-email", "short");
    fireEvent.click(screen.getByRole("button", { name: "로그인" }));

    expect(await screen.findByText("로그인에 실패했어요")).toBeInTheDocument();
    expect(loginMock).not.toHaveBeenCalled();
  });
});
