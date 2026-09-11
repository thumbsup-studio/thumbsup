import { useEffect } from "react";
import { AccessibilityInfo, Text } from "react-native";
import Animated, {
  cancelAnimation,
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from "react-native-reanimated";

import { useReducedMotion } from "./use-reduced-motion";

const particles = [
  { glyph: "●", left: "8%" },
  { glyph: "◆", left: "22%" },
  { glyph: "▲", left: "38%" },
  { glyph: "●", left: "55%" },
  { glyph: "◆", left: "70%" },
  { glyph: "▲", left: "86%" },
] as const;

export function CelebrationParticles({ praise, visible }: { praise: string; visible: boolean }) {
  const reduceMotion = useReducedMotion();

  useEffect(() => {
    if (visible) AccessibilityInfo.announceForAccessibility(praise);
  }, [praise, visible]);

  if (!visible || reduceMotion) return null;
  return (
    <Animated.View
      pointerEvents="none"
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      className="absolute inset-0 z-20"
    >
      {particles.map((particle, index) => (
        <Particle index={index} key={`${praise}-${particle.left}`} particle={particle} />
      ))}
    </Animated.View>
  );
}

function Particle({ index, particle }: { index: number; particle: (typeof particles)[number] }) {
  const progress = useSharedValue(0);
  useEffect(() => {
    progress.value = 0;
    progress.value = withTiming(1, {
      duration: 1800 + index * 80,
      easing: Easing.out(Easing.quad),
    });
    return () => cancelAnimation(progress);
  }, [index, progress]);
  const style = useAnimatedStyle(() => ({
    opacity: Math.min(progress.value * 10, 1) * (1 - progress.value),
    transform: [
      { translateY: progress.value * (260 + index * 18) },
      { translateX: Math.sin(progress.value * Math.PI) * (index % 2 ? 24 : -24) },
      { rotate: `${progress.value * 240 + index * 19}deg` },
    ],
  }));
  return (
    <Animated.View className="absolute top-12" style={[{ left: particle.left }, style]}>
      <Text className={index % 2 === 0 ? "text-2xl text-primary" : "text-2xl text-accent"}>
        {particle.glyph}
      </Text>
    </Animated.View>
  );
}
