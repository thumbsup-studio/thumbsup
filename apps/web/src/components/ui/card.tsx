import type { ComponentProps } from "react";

type CardVariant = "surface" | "hero";

const VARIANT: Record<CardVariant, string> = {
  surface: "bg-surface text-ink shadow-card border border-border",
  hero: "bg-primary text-primary-fg shadow-hero",
};

type CardProps = ComponentProps<"div"> & { variant?: CardVariant };

export function Card({ variant = "surface", className = "", ...props }: CardProps) {
  return <div className={`rounded-card p-5 ${VARIANT[variant]} ${className}`} {...props} />;
}
