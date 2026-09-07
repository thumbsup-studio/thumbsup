import { Redirect } from "expo-router";
import type { ReactNode } from "react";

export function StagingUpdateProvider({ children }: { children: ReactNode }) {
  return children;
}

export default function ProductionChannelStub() {
  return <Redirect href="/" />;
}
