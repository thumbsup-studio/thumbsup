import { render, screen } from "@testing-library/react";
import { getProgressPercent } from "@thumbsup/core";
import { tokens } from "@thumbsup/tokens";
import { Button } from "@thumbsup/ui-web";
import { describe, expect, it } from "vitest";

describe("shared package public boundaries", () => {
  it("uses core only through its public entrypoint", () => {
    expect(getProgressPercent(1, 4)).toBe(50);
  });

  it("uses typed token values through the public entrypoint", () => {
    expect(tokens.color.primary).toBe("#2f63ff"); // design-ok: SSOT 공개값 계약 검증
  });

  it("renders ui-web through the public entrypoint", () => {
    render(<Button>계속하기</Button>);
    expect(screen.getByRole("button", { name: "계속하기" })).toBeInTheDocument();
  });
});
