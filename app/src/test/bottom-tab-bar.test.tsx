import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { BottomTabBar } from "@/features/home/components/bottom-tab-bar";

describe("BottomTabBar", () => {
  it("uses the full home png icon when the home tab is active", () => {
    render(<BottomTabBar activeTab="home" onHistoryClick={() => {}} onProfileClick={() => {}} />);

    const homeTab = screen.getByRole("button", { name: "홈" });
    const historyTab = screen.getByRole("button", { name: "히스토리" });
    const homeIcon = homeTab.querySelector('img[alt=""]');
    const historyIcon = historyTab.querySelector('img[alt=""]');

    expect(homeTab).toHaveAttribute("aria-current", "page");
    expect(homeTab).toHaveAttribute("data-state", "active");
    expect(historyTab).toHaveAttribute("data-state", "inactive");
    expect(homeTab.querySelector("[data-icon-variant]")).toHaveAttribute(
      "data-icon-variant",
      "full",
    );
    expect(historyTab.querySelector("[data-icon-variant]")).toHaveAttribute(
      "data-icon-variant",
      "empty",
    );
    expect(homeIcon).toHaveAttribute("src", "/icons/tabs/home-full.png");
    expect(historyIcon).toHaveAttribute("src", "/icons/tabs/history-empty.png");
  });

  it("uses the full history png icon when the history tab is active", () => {
    render(
      <BottomTabBar activeTab="history" onHistoryClick={() => {}} onProfileClick={() => {}} />,
    );

    const historyTab = screen.getByRole("button", { name: "히스토리" });
    const profileTab = screen.getByRole("button", { name: "프로필" });
    const historyIcon = historyTab.querySelector('img[alt=""]');

    expect(historyTab).toHaveAttribute("aria-current", "page");
    expect(historyTab).toHaveAttribute("data-state", "active");
    expect(profileTab).toHaveAttribute("data-state", "inactive");
    expect(historyTab.querySelector("[data-icon-variant]")).toHaveAttribute(
      "data-icon-variant",
      "full",
    );
    expect(historyIcon).toHaveAttribute("src", "/icons/tabs/history-full.png");
  });
});
