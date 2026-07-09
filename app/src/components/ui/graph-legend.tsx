import { MASTERY_LABEL, MasteryIcon, type MasteryLevel } from "./graph-node";

const ITEMS: MasteryLevel[] = ["unlearned", "learning", "master"];

export function GraphLegend() {
  return (
    <ul className="flex items-center justify-center gap-5 text-xs font-medium text-graph-fg-muted">
      {ITEMS.map((mastery) => (
        <li className="flex items-center gap-1.5" key={mastery}>
          <MasteryIcon mastery={mastery} />
          <span>{MASTERY_LABEL[mastery]}</span>
        </li>
      ))}
    </ul>
  );
}
