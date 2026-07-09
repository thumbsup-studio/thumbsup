import { render } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { RequireAuth } from "@/features/auth/require-auth";
import { tokenStore } from "@/lib/api";

const { replaceMock } = vi.hoisted(() => ({ replaceMock: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ replace: replaceMock }) }));

beforeEach(() => {
  replaceMock.mockClear();
  localStorage.clear();
});

describe("RequireAuth", () => {
  it("토큰이 없으면(미로그인) /login으로 replace한다", () => {
    render(<RequireAuth />);

    expect(replaceMock).toHaveBeenCalledWith("/login");
  });

  it("토큰이 있으면(로그인 상태) 리다이렉트하지 않는다", () => {
    tokenStore.set({ accessToken: "a", refreshToken: "r" });

    render(<RequireAuth />);

    expect(replaceMock).not.toHaveBeenCalled();
  });
});
