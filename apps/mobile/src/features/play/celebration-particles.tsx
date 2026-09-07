import { useEffect } from "react";
import { AccessibilityInfo, Text, View } from "react-native";
import Animated, { FadeIn, FadeOut } from "react-native-reanimated";

import { useReducedMotion } from "./use-reduced-motion";

const particles = [
  { glyph: "●", left: "8%", top: "10%" },
  { glyph: "◆", left: "22%", top: "18%" },
  { glyph: "▲", left: "38%", top: "7%" },
  { glyph: "●", left: "55%", top: "15%" },
  { glyph: "◆", left: "70%", top: "8%" },
  { glyph: "▲", left: "86%", top: "20%" },
] as const;

export function CelebrationParticles({ praise, visible }: { praise: string; visible: boolean }) {
  const reduceMotion = useReducedMotion();

  useEffect(() => {
    if (visible) AccessibilityInfo.announceForAccessibility(praise);
  }, [praise, visible]);

  if (!visible || reduceMotion) return null;
  return (
    <Animated.View
      entering={FadeIn.duration(180)}
      exiting={FadeOut.duration(180)}
      pointerEvents="none"
      className="absolute inset-0 z-20"
    >
      {particles.map((particle, index) => (
        <View
          className="absolute"
          key={`${particle.left}-${particle.glyph}`}
          style={{
            left: particle.left,
            top: particle.top,
            transform: [{ rotate: `${index * 19}deg` }],
          }}
        >
          <Text className={index % 2 === 0 ? "text-2xl text-primary" : "text-2xl text-accent"}>
            {particle.glyph}
          </Text>
        </View>
      ))}
    </Animated.View>
  );
}
