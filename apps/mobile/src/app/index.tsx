import { Redirect } from "expo-router";
import { useApi } from "../lib/api/api-provider";

export default function Index() {
  const { sessionStatus } = useApi();
  return <Redirect href={sessionStatus === "authenticated" ? "/(tabs)" : "/(auth)/login"} />;
}
