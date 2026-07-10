"use client";

import { useEffect, useId, useMemo, useRef, useState } from "react";
import type { AnnotatedText, FollowUpKeyword } from "@/features/play/types";

type Keyword = {
  term: string;
  description: string;
};

type KeywordTooltipTextProps = {
  keywords: Keyword[];
  text: string;
};

type AnnotatedTooltipTextProps = {
  annotated: AnnotatedText;
  keywords: FollowUpKeyword[];
};

const tooltipOpenEventName = "thumbsup:keyword-tooltip-open";
const keywordWordChars = String.raw`\p{L}\p{N}`;
const koreanParticle = "(?:은|는|이|가|을|를|와|과|으로|로|이나)";

/** 두 렌더러(정규식 매칭·서버 오프셋)가 공유하는 조각 형태. description이 있으면 키워드 버튼, 없으면 평문. */
type TextPart = {
  key: string;
  value: string;
  description?: string;
};

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function getKeywordTermPattern(term: string) {
  const escapedTerm = escapeRegExp(term);

  if (term.length <= 1) {
    return `(?<![${keywordWordChars}])${escapedTerm}(?=$|[^${keywordWordChars}]|${koreanParticle})`;
  }

  return escapedTerm;
}

function getKeywordPattern(keywords: Keyword[]) {
  const terms = keywords
    .map((keyword) => keyword.term.trim())
    .filter(Boolean)
    .sort((a, b) => b.length - a.length)
    .map(getKeywordTermPattern);

  return terms.length > 0 ? new RegExp(`(${terms.join("|")})`, "gu") : null;
}

/** insight용: mock 키워드({term,description})를 정규식으로 찾아 조각을 만든다. */
function getTextParts(text: string, keywords: Keyword[]): TextPart[] {
  const pattern = getKeywordPattern(keywords);

  if (!pattern) {
    return [{ key: "text-0", value: text }];
  }

  const descriptionByTerm = new Map(keywords.map((keyword) => [keyword.term, keyword.description]));
  const parts: TextPart[] = [];
  let cursor = 0;

  for (const match of text.matchAll(pattern)) {
    const value = match[0];
    const start = match.index;
    const end = start + value.length;

    if (start > cursor) {
      parts.push({
        key: `text-${cursor}-${start}`,
        value: text.slice(cursor, start),
      });
    }

    parts.push({
      key: `keyword-${start}-${end}`,
      value,
      description: descriptionByTerm.get(value),
    });
    cursor = end;
  }

  if (cursor < text.length) {
    parts.push({
      key: `text-${cursor}-${text.length}`,
      value: text.slice(cursor),
    });
  }

  return parts;
}

/** follow-up용: 서버가 내려준 start/end 오프셋으로 조각을 슬라이스한다(재검증 없이 서버 불변식을 신뢰). */
function getAnnotatedParts(annotated: AnnotatedText, keywords: FollowUpKeyword[]): TextPart[] {
  const { text, highlights } = annotated;

  if (highlights.length === 0) {
    return [{ key: "text-0", value: text }];
  }

  const descriptionByKeyword = new Map(
    keywords.map((keyword) => [keyword.keyword, keyword.description]),
  );
  const parts: TextPart[] = [];
  let cursor = 0;

  for (const highlight of highlights) {
    if (highlight.start > cursor) {
      parts.push({
        key: `text-${cursor}-${highlight.start}`,
        value: text.slice(cursor, highlight.start),
      });
    }

    parts.push({
      key: `keyword-${highlight.start}-${highlight.end}`,
      value: text.slice(highlight.start, highlight.end),
      description: descriptionByKeyword.get(highlight.keyword),
    });
    cursor = highlight.end;
  }

  if (cursor < text.length) {
    parts.push({
      key: `text-${cursor}-${text.length}`,
      value: text.slice(cursor),
    });
  }

  return parts;
}

/** 팝오버 UI+상호작용(외부클릭/Escape 닫기, 하나만 열기)을 공유하는 렌더러. */
function TooltipParts({ parts }: { parts: TextPart[] }) {
  const [openId, setOpenId] = useState<string | null>(null);
  const instanceId = useId();
  const rootRef = useRef<HTMLSpanElement>(null);

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
        if (!part.description) {
          return <span key={part.key}>{part.value}</span>;
        }

        const description = part.description;
        const tooltipId = `${instanceId}-${part.key}`;
        const isOpen = openId === tooltipId;

        return (
          <span className="relative inline-flex" key={tooltipId}>
            <button
              aria-describedby={isOpen ? tooltipId : undefined}
              aria-expanded={isOpen}
              aria-label={`${part.value} 설명 보기`}
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
                className="absolute left-0 top-full z-20 mt-2 w-64 rounded-control border border-border bg-ink px-3 py-2 text-xs font-semibold leading-5 text-primary-fg shadow-card"
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

/** insight 화면 전용(정규식 키워드 매칭). mock 데이터가 오프셋을 안 주므로 이 방식을 유지한다. */
export function KeywordTooltipText({ keywords, text }: KeywordTooltipTextProps) {
  const parts = useMemo(() => getTextParts(text, keywords), [keywords, text]);

  return <TooltipParts parts={parts} />;
}

/** follow-up 화면 전용(서버 offsets 기반). */
export function AnnotatedTooltipText({ annotated, keywords }: AnnotatedTooltipTextProps) {
  const parts = useMemo(() => getAnnotatedParts(annotated, keywords), [annotated, keywords]);

  return <TooltipParts parts={parts} />;
}
