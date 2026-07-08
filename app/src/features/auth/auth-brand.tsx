import { ThumbsUpIcon } from "@/components/icons";

/** 로그인·회원가입 공통 상단 브랜드 블록(앱 마크 + 제목 + 부제). */
export function AuthBrand({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <div className="flex flex-col items-center gap-3 text-center">
      <span className="inline-flex size-16 items-center justify-center rounded-control bg-primary text-primary-fg shadow-hero">
        <ThumbsUpIcon className="size-8" />
      </span>
      <div className="flex flex-col gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight text-ink">{title}</h1>
        <p className="text-base text-ink-muted">{subtitle}</p>
      </div>
    </div>
  );
}
