"use client";

import { useEffect, useId, useMemo, useRef, useState } from "react";

type Keyword = {
  term: string;
  description: string;
};

type KeywordTooltipTextProps = {
  keywords: Keyword[];
  text: string;
};

const tooltipOpenEventName = "thumbsup:keyword-tooltip-open";

type TextPart = {
  key: string;
  value: string;
};

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function getKeywordPattern(keywords: Keyword[]) {
  const terms = keywords
    .map((keyword) => keyword.term.trim())
    .filter(Boolean)
    .sort((a, b) => b.length - a.length)
    .map(escapeRegExp);

  return terms.length > 0 ? new RegExp(`(${terms.join("|")})`, "g") : null;
}

function getTextParts(text: string, keywords: Keyword[]): TextPart[] {
  const pattern = getKeywordPattern(keywords);

  if (!pattern) {
    return [{ key: "text-0", value: text }];
  }

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

export function KeywordTooltipText({ keywords, text }: KeywordTooltipTextProps) {
  const [openId, setOpenId] = useState<string | null>(null);
  const instanceId = useId();
  const rootRef = useRef<HTMLSpanElement>(null);
  const keywordMap = useMemo(
    () => new Map(keywords.map((keyword) => [keyword.term, keyword])),
    [keywords],
  );
  const parts = useMemo(() => getTextParts(text, keywords), [keywords, text]);

  useEffect(() => {
    function closeOnOutsideClick(event: PointerEvent) {
      if (!rootRef.current?.contains(event.target as Node)) {
        setOpenId(null);
      }
    }

    function closeWhenAnotherTooltipOpens(event: Event) {
      const openedId = (event as CustomEvent<string>).detail;

      setOpenId((currentId) => (currentId && currentId !== openedId ? null : currentId));
    }

    document.addEventListener("pointerdown", closeOnOutsideClick);
    window.addEventListener(tooltipOpenEventName, closeWhenAnotherTooltipOpens);

    return () => {
      document.removeEventListener("pointerdown", closeOnOutsideClick);
      window.removeEventListener(tooltipOpenEventName, closeWhenAnotherTooltipOpens);
    };
  }, []);

  return (
    <span ref={rootRef}>
      {parts.map((part) => {
        const keyword = keywordMap.get(part.value);

        if (!keyword) {
          return <span key={part.key}>{part.value}</span>;
        }

        const tooltipId = `${instanceId}-${part.key}`;
        const isOpen = openId === tooltipId;

        return (
          <span className="relative inline-flex" key={tooltipId}>
            <button
              aria-describedby={isOpen ? tooltipId : undefined}
              aria-expanded={isOpen}
              aria-label={`${keyword.term} 설명 보기`}
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
                {keyword.description}
              </span>
            ) : null}
          </span>
        );
      })}
    </span>
  );
}
