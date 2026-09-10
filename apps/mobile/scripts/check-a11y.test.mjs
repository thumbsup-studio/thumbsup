import { describe, expect, it } from "vitest";
import { scanSource } from "./check-a11y.mjs";

describe("check-a11y", () => {
  it("accepts a role with an accessibility label", () => {
    expect(
      scanSource('<TextInput accessibilityRole="search" accessibilityLabel="검색" />'),
    ).toEqual([]);
  });

  it("accepts literal text rendered by a child", () => {
    expect(
      scanSource(`
        <Pressable accessibilityRole="button">
          <Text>다시 시도</Text>
        </Pressable>
      `),
    ).toEqual([]);
  });

  it("reports each missing property with the source line", () => {
    expect(scanSource("\n<Switch value={enabled} />", "toggle.tsx")).toEqual([
      {
        element: "Switch",
        file: "toggle.tsx",
        line: 2,
        missing: ["accessibilityRole", "accessibilityLabel 또는 리터럴 텍스트"],
      },
    ]);
  });

  it("does not treat dynamic children as a literal label", () => {
    const [violation] = scanSource(`
      <Pressable accessibilityRole="button">
        <Text>{label}</Text>
      </Pressable>
    `);
    expect(violation.missing).toEqual(["accessibilityLabel 또는 리터럴 텍스트"]);
  });

  it("allows a reasoned exception on the same or previous line", () => {
    expect(
      scanSource(`
        // a11y-ok: labeled parent owns this wrapped action
        <Pressable onPress={close} />
        <Button onPress={close} /> // a11y-ok: labeled parent owns this wrapped action
      `),
    ).toEqual([]);
  });
});
