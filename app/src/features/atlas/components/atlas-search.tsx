import { SearchIcon } from "@/components/icons";

type AtlasSearchProps = {
  value: string;
  onChange: (value: string) => void;
};

export function AtlasSearch({ value, onChange }: AtlasSearchProps) {
  return (
    <label className="flex items-center gap-2 rounded-control border border-border bg-surface px-4 py-3 text-ink-muted">
      <SearchIcon />
      <span className="sr-only">개념 검색</span>
      <input
        className="min-h-6 w-full bg-transparent text-sm text-ink outline-none placeholder:text-ink-muted"
        onChange={(event) => onChange(event.target.value)}
        placeholder="개념 검색"
        type="search"
        value={value}
      />
    </label>
  );
}
