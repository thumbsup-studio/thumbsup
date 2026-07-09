import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { SignupForm } from "@/features/auth/signup-form";
import { ApiError, signup } from "@/lib/api";
import { AppToastProvider } from "@/providers/app-toast-provider";

const renderForm = () => render(<SignupForm />, { wrapper: AppToastProvider });

const { pushMock } = vi.hoisted(() => ({ pushMock: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: pushMock }) }));
vi.mock("@/lib/api", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api")>();
  return { ...actual, signup: vi.fn() };
});

const signupMock = vi.mocked(signup);

function fillForm({
  email = "user@example.com",
  password = "password123",
  confirm = "password123",
  agree = true,
}: {
  email?: string;
  password?: string;
  confirm?: string;
  agree?: boolean;
} = {}) {
  fireEvent.change(screen.getByLabelText("이메일"), { target: { value: email } });
  fireEvent.change(screen.getByLabelText("비밀번호"), { target: { value: password } });
  fireEvent.change(screen.getByLabelText("비밀번호 확인"), { target: { value: confirm } });
  if (agree) fireEvent.click(screen.getByRole("checkbox"));
}

beforeEach(() => {
  pushMock.mockClear();
  signupMock.mockReset();
});

describe("SignupForm", () => {
  it("유효 입력 + 약관 동의 시 signup을 호출하고 홈으로 이동한다(자동 로그인)", async () => {
    signupMock.mockResolvedValue({ accessToken: "a", refreshToken: "r" });
    renderForm();

    fillForm();
    fireEvent.click(screen.getByRole("button", { name: "가입하기" }));

    await waitFor(() => expect(pushMock).toHaveBeenCalledWith("/"));
    expect(signupMock).toHaveBeenCalledWith("user@example.com", "password123");
  });

  it("비밀번호가 일치하지 않으면 확인 필드 에러를 보이고 API를 호출하지 않는다", async () => {
    renderForm();

    fillForm({ confirm: "different1" });
    fireEvent.click(screen.getByRole("button", { name: "가입하기" }));

    expect(await screen.findByText("비밀번호가 일치하지 않아요.")).toBeInTheDocument();
    expect(signupMock).not.toHaveBeenCalled();
  });

  it("약관에 동의하지 않으면 동의 요청 에러를 보이고 API를 호출하지 않는다", async () => {
    renderForm();

    fillForm({ agree: false });
    fireEvent.click(screen.getByRole("button", { name: "가입하기" }));

    expect(await screen.findByText("약관 동의가 필요해요")).toBeInTheDocument();
    expect(signupMock).not.toHaveBeenCalled();
  });

  it("409 중복이면 이메일 필드에 '이미 가입된 이메일이에요.'를 표시한다", async () => {
    signupMock.mockRejectedValue(
      new ApiError({ code: "USER_EMAIL_DUPLICATED", status: 409, message: "중복" }),
    );
    renderForm();

    fillForm();
    fireEvent.click(screen.getByRole("button", { name: "가입하기" }));

    expect(await screen.findByText("이미 가입된 이메일이에요.")).toBeInTheDocument();
    expect(screen.getByLabelText("이메일")).toHaveAttribute("aria-invalid", "true");
    expect(pushMock).not.toHaveBeenCalled();
  });
});
