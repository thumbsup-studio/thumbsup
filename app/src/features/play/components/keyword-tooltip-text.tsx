"use client";

import { useEffect, useId, useMemo, useRef, useState } from "react";
import type { AnnotatedText, QuizKeyword } from "@/lib/api/quiz";

type KeywordTooltipTextProps = {
  dict: Map<string, string>;
  node: AnnotatedText;
};

const tooltipOpenEventName = "thumbsup:keyword-tooltip-open";

type TextPart =
  | {
      kind: "text";
      key: string;
      value: string;
    }
  | {
      kind: "keyword";
      key: string;
      keyword: string;
      value: string;
    };

export function getKeywordDescriptionMap(keywords: QuizKeyword[]) {
  return new Map(keywords.map((keyword) => [keyword.keyword, keyword.description]));
}

function getTextParts(node: AnnotatedText): TextPart[] {
  const parts: TextPart[] = [];
  let cursor = 0;

  for (const highlight of node.highlights) {
    if (highlight.start > cursor) {
      parts.push({
        kind: "text",
        key: `text-${cursor}-${highlight.start}`,
        value: node.text.slice(cursor, highlight.start),
      });
    }

    parts.push({
      kind: "keyword",
      key: `keyword-${highlight.start}-${highlight.end}`,
      keyword: highlight.keyword,
      value: node.text.slice(highlight.start, highlight.end),
    });
    cursor = highlight.end;
  }

  if (cursor < node.text.length) {
    parts.push({
      kind: "text",
      key: `text-${cursor}-${node.text.length}`,
      value: node.text.slice(cursor),
    });
  }

  return parts.length > 0 ? parts : [{ kind: "text", key: "text-0", value: node.text }];
}

export function KeywordTooltipText({ dict, node }: KeywordTooltipTextProps) {
  const [openId, setOpenId] = useState<string | null>(null);
  const instanceId = useId();
  const rootRef = useRef<HTMLSpanElement>(null);
  const parts = useMemo(() => getTextParts(node), [node]);

  useEffect(() => {
    function closeOnOutsideClick(event: PointerEvent) {
      if (!rootRef.current?.contains(event.target as Node)) {
        setOpenId(null);
      }
    }

    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setOpenId(null);
      }
    }

    function closeWhenAnotherTooltipOpens(event: Event) {
      const openedId = (event as CustomEvent<string>).detail;

      setOpenId((currentId) => (currentId && currentId !== openedId ? null : currentId));
    }

    document.addEventListener("pointerdown", closeOnOutsideClick);
    document.addEventListener("keydown", closeOnEscape);
    window.addEventListener(tooltipOpenEventName, closeWhenAnotherTooltipOpens);

    return () => {
      document.removeEventListener("pointerdown", closeOnOutsideClick);
      document.removeEventListener("keydown", closeOnEscape);
      window.removeEventListener(tooltipOpenEventName, closeWhenAnotherTooltipOpens);
    };
  }, []);

  return (
    <span ref={rootRef}>
      {parts.map((part) => {
        if (part.kind === "text") {
          return <span key={part.key}>{part.value}</span>;
        }

        const description = dict.get(part.keyword) ?? "";
        const tooltipId = `${instanceId}-${part.key}`;
        const isOpen = openId === tooltipId;

        return (
          <span className="relative inline-flex" key={tooltipId}>
            <button
              aria-describedby={isOpen ? tooltipId : undefined}
              aria-expanded={isOpen}
              aria-label={`${part.keyword} 설명 보기`}
              className="inline border-0 bg-transparent p-0 font-bold text-primary underline decoration-primary underline-offset-4"
              onClick={() => {
                if (isOpen) {
                  setOpenId(null);
                  return;
                }

                window.dispatchEvent(new CustomEvent(tooltipOpenEventName, { detail: tooltipId }));
                setOpenId(tooltipId);
              }}
              type="button"
            >
              {part.value}
            </button>
            {isOpen ? (
              <span
                className="absolute left-0 top-full z-20 mt-2 w-64 rounded-control border border-border bg-surface px-3 py-2 text-xs font-semibold leading-5 text-ink shadow-card"
                id={tooltipId}
                role="tooltip"
              >
                {description}
              </span>
            ) : null}
          </span>
        );
      })}
    </span>
  );
}
