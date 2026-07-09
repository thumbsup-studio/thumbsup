import { ChevronLeftIcon, ShareIcon } from "@/components/icons";

type AtlasHeaderProps = {
  onBack: () => void;
  onShare: () => void;
};

export function AtlasHeader({ onBack, onShare }: AtlasHeaderProps) {
  return (
    <header className="sticky top-0 z-10 -mx-4 flex items-center justify-between bg-bg px-4 py-2 sm:-mx-6 sm:px-6">
      <button
        aria-label="뒤로 가기"
        className="flex size-10 items-center justify-center rounded-control text-ink"
        onClick={onBack}
        type="button"
      >
        <ChevronLeftIcon />
      </button>
      <h1 className="text-base font-semibold text-ink">지식 그래프</h1>
      <button
        aria-label="공유하기"
        className="flex size-10 items-center justify-center rounded-control text-ink"
        onClick={onShare}
        type="button"
      >
        <ShareIcon />
      </button>
    </header>
  );
}
