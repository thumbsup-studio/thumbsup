import { Chip } from "@/components/ui/chip";
import type { AtlasCategory } from "@/features/atlas/types";

type CategoryFilterProps = {
  categories: AtlasCategory[];
  activeCategoryId: string;
  onSelect: (categoryId: string) => void;
};

export function CategoryFilter({ categories, activeCategoryId, onSelect }: CategoryFilterProps) {
  return (
    <fieldset className="flex gap-2 overflow-x-auto border-0 p-0 pb-1">
      <legend className="sr-only">카테고리 필터</legend>
      {categories.map((category) => {
        const isActive = category.id === activeCategoryId;
        return (
          <button
            aria-pressed={isActive}
            key={category.id}
            onClick={() => onSelect(category.id)}
            type="button"
          >
            <Chip className="whitespace-nowrap" tone={isActive ? "primary" : "neutral"}>
              {isActive ? "✓ " : ""}
              {category.label}
            </Chip>
          </button>
        );
      })}
    </fieldset>
  );
}
