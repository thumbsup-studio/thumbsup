import type { AnnotatedText, QuizKeyword } from "@thumbsup/api";
import { useMemo, useState } from "react";
import { Modal, Pressable, Text, View } from "react-native";

type Part =
  | { key: string; kind: "text"; value: string }
  | { key: string; kind: "keyword"; keyword: string; value: string };

function splitText(node: AnnotatedText): Part[] {
  const parts: Part[] = [];
  let cursor = 0;
  for (const highlight of node.highlights) {
    if (highlight.start > cursor) {
      parts.push({
        key: `text-${cursor}`,
        kind: "text",
        value: node.text.slice(cursor, highlight.start),
      });
    }
    parts.push({
      key: `keyword-${highlight.start}-${highlight.end}`,
      keyword: highlight.keyword,
      kind: "keyword",
      value: node.text.slice(highlight.start, highlight.end),
    });
    cursor = highlight.end;
  }
  if (cursor < node.text.length)
    parts.push({ key: `text-${cursor}`, kind: "text", value: node.text.slice(cursor) });
  return parts.length ? parts : [{ key: "text-0", kind: "text", value: node.text }];
}

export function AnnotatedParagraph({
  node,
  keywords,
}: {
  node: AnnotatedText;
  keywords: QuizKeyword[];
}) {
  const [openKeyword, setOpenKeyword] = useState<string | null>(null);
  const parts = useMemo(() => splitText(node), [node]);
  const description =
    keywords.find((keyword) => keyword.keyword === openKeyword)?.description ?? "";

  return (
    <>
      <View className="flex-row flex-wrap items-baseline">
        {parts.map((part) =>
          part.kind === "text" ? (
            <Text className="text-sm leading-6 text-ink-muted" key={part.key}>
              {part.value}
            </Text>
          ) : (
            <Pressable
              accessibilityLabel={`${part.keyword} 설명 보기`}
              accessibilityRole="button"
              key={part.key}
              onPress={() => setOpenKeyword(part.keyword)}
            >
              <Text className="text-sm font-bold leading-6 text-primary underline">
                {part.value}
              </Text>
            </Pressable>
          ),
        )}
      </View>
      <Modal
        animationType="fade"
        onRequestClose={() => setOpenKeyword(null)}
        transparent
        visible={openKeyword !== null}
      >
        <View className="flex-1 items-center justify-center bg-ink px-5">
          <View accessibilityViewIsModal className="w-full rounded-card bg-surface p-5">
            <Text accessibilityRole="header" className="text-xl font-black text-ink">
              {openKeyword}
            </Text>
            <Text className="mt-2 leading-6 text-ink-muted">{description}</Text>
            <Pressable
              accessibilityLabel="키워드 설명 닫기"
              accessibilityRole="button"
              className="mt-5 min-h-12 items-center justify-center rounded-control bg-primary"
              onPress={() => setOpenKeyword(null)}
            >
              <Text className="font-bold text-primary-fg">확인</Text>
            </Pressable>
          </View>
        </View>
      </Modal>
    </>
  );
}
