import { fireEvent, render } from "@testing-library/react-native";

import {
  BlankQuestion,
  CodeReadingQuestion,
  DescriptiveQuestion,
  MatchingQuestion,
  OxQuestion,
} from "./question-components";

const choices = [
  { choiceId: 1, content: "프로세스", displayOrder: 1 },
  { choiceId: 2, content: "스레드", displayOrder: 2 },
];

describe("문제 유형별 답 선택 흐름", () => {
  it("OX 문제에서 O를 선택한다", async () => {
    const onDraftChange = jest.fn();
    const screen = await render(
      <OxQuestion disabled={false} draft={null} onDraftChange={onDraftChange} />,
    );

    await fireEvent.press(screen.getByRole("radio", { name: "O, 맞다" }));
    expect(onDraftChange).toHaveBeenCalledWith(true);
  });

  it("매칭 문제에서 선택지를 고른다", async () => {
    const onDraftChange = jest.fn();
    const screen = await render(
      <MatchingQuestion
        choices={choices}
        disabled={false}
        draft={null}
        onDraftChange={onDraftChange}
      />,
    );

    await fireEvent.press(screen.getByRole("radio", { name: "B. 스레드" }));
    expect(onDraftChange).toHaveBeenCalledWith("2");
  });

  it("서술형 문제에서 답을 입력한다", async () => {
    const onDraftChange = jest.fn();
    const screen = await render(
      <DescriptiveQuestion
        blankHints={null}
        disabled={false}
        draft={[]}
        onDraftChange={onDraftChange}
      />,
    );

    await fireEvent.changeText(screen.getByLabelText("서술형 답안"), "운영체제의 실행 단위");
    expect(onDraftChange).toHaveBeenCalledWith(["운영체제의 실행 단위"]);
  });

  it("빈칸 문제에서 모든 키워드를 입력한다", async () => {
    const onDraftChange = jest.fn();
    const screen = await render(
      <BlankQuestion
        blankCount={2}
        blankHints={null}
        disabled={false}
        draft={[]}
        onDraftChange={onDraftChange}
      />,
    );

    await fireEvent.changeText(screen.getByLabelText("핵심 키워드 1"), "임계 구역");
    expect(onDraftChange).toHaveBeenLastCalledWith(["임계 구역", ""]);
    await screen.rerender(
      <BlankQuestion
        blankCount={2}
        blankHints={null}
        disabled={false}
        draft={["임계 구역", ""]}
        onDraftChange={onDraftChange}
      />,
    );
    await fireEvent.changeText(screen.getByLabelText("핵심 키워드 2"), "락");
    expect(onDraftChange).toHaveBeenLastCalledWith(["임계 구역", "락"]);
  });

  it("코드 리딩 문제에서 코드를 읽고 선택지를 고른다", async () => {
    const onDraftChange = jest.fn();
    const screen = await render(
      <CodeReadingQuestion
        choices={choices}
        code="const value = 1"
        disabled={false}
        draft={null}
        onDraftChange={onDraftChange}
      />,
    );

    expect(screen.getByLabelText("문제 코드")).toBeTruthy();
    await fireEvent.press(screen.getByRole("radio", { name: "A. 프로세스" }));
    expect(onDraftChange).toHaveBeenCalledWith("1");
  });
});
