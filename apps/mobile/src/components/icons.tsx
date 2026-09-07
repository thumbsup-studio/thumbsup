import { tokens } from "@thumbsup/tokens";
import type { ComponentProps } from "react";
import type { ColorValue } from "react-native";
import Svg, { Circle, Ellipse, Path, Rect } from "react-native-svg";

type IconProps = ComponentProps<typeof Svg> & { color?: ColorValue };

function StrokeIcon({ color = tokens.color["ink-muted"], ...props }: IconProps) {
  return (
    <Svg
      accessibilityElementsHidden
      fill="none"
      importantForAccessibility="no-hide-descendants"
      stroke={color}
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={2}
      viewBox="0 0 24 24"
      {...props}
    />
  );
}

export function HomeIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <Path d="m3 11 9-8 9 8" />
      <Path d="M5 10v10h14V10" />
      <Path d="M9 20v-6h6v6" />
    </StrokeIcon>
  );
}

export function CourseIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <Path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
      <Path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2Z" />
    </StrokeIcon>
  );
}

export function HistoryIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <Path d="M3 12a9 9 0 1 0 3-6.7L3 8" />
      <Path d="M3 3v5h5" />
      <Path d="M12 7v5l3 2" />
    </StrokeIcon>
  );
}

export function UserIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <Path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2" />
      <Circle cx={12} cy={7} r={4} />
    </StrokeIcon>
  );
}

export function ChevronRightIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <Path d="m9 18 6-6-6-6" />
    </StrokeIcon>
  );
}

export function LockIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <Rect height={11} rx={2} width={18} x={3} y={11} />
      <Path d="M7 11V7a5 5 0 0 1 10 0v4" />
    </StrokeIcon>
  );
}

export function AlertCircleIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <Circle cx={12} cy={12} r={10} />
      <Path d="M12 8v4" />
      <Path d="M12 16h.01" />
    </StrokeIcon>
  );
}

export function WifiOffIcon(props: IconProps) {
  return (
    <StrokeIcon {...props}>
      <Path d="M2 8.82a15 15 0 0 1 4.17-2.65" />
      <Path d="M10.66 5c4.01-.36 8.02.92 11.34 3.82" />
      <Path d="M5 12.86a10 10 0 0 1 3.24-1.9" />
      <Path d="M13.41 10.53A10 10 0 0 1 19 12.86" />
      <Path d="M8.5 16.43a5 5 0 0 1 7 0" />
      <Path d="M12 20h.01" />
      <Path d="m2 2 20 20" />
    </StrokeIcon>
  );
}

export type CharacterMood = "happy" | "neutral" | "hungry";

const mouthPath: Record<CharacterMood, string> = {
  happy: "M26,44 Q32,50 38,44",
  neutral: "M28,45 Q32,47 36,45",
  hungry: "M28,47 Q32,43 36,47",
};

export function DogIcon({ mood = "neutral", ...props }: IconProps & { mood?: CharacterMood }) {
  return (
    <Svg
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      viewBox="0 0 64 64"
      {...props}
    >
      <Path d="M10,32 Q7,10 25,19 Q22,29 10,32 Z" fill={tokens.color["character-fur"]} />
      <Path d="M54,32 Q57,10 39,19 Q42,29 54,32 Z" fill={tokens.color["character-fur"]} />
      <Circle cx={32} cy={34} fill={tokens.color["character-fur"]} r={21} />
      <Circle cx={18} cy={38} fill={tokens.color["character-blush"]} opacity={0.8} r={3} />
      <Circle cx={46} cy={38} fill={tokens.color["character-blush"]} opacity={0.8} r={3} />
      <Ellipse cx={32} cy={41} fill={tokens.color["character-muzzle"]} rx={13} ry={10} />
      {mood === "happy" ? (
        <>
          <Path
            d="M21,30 Q24,26 27,30"
            fill="none"
            stroke={tokens.color["character-nose"]}
            strokeLinecap="round"
            strokeWidth={2}
          />
          <Path
            d="M37,30 Q40,26 43,30"
            fill="none"
            stroke={tokens.color["character-nose"]}
            strokeLinecap="round"
            strokeWidth={2}
          />
        </>
      ) : (
        <>
          <Circle cx={24} cy={30} fill={tokens.color["character-nose"]} r={2.2} />
          <Circle cx={40} cy={30} fill={tokens.color["character-nose"]} r={2.2} />
        </>
      )}
      <Ellipse cx={32} cy={37} fill={tokens.color["character-nose"]} rx={3.5} ry={3} />
      <Path
        d={mouthPath[mood]}
        fill="none"
        stroke={tokens.color["character-nose"]}
        strokeLinecap="round"
        strokeWidth={2}
      />
    </Svg>
  );
}
