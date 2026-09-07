import { Redirect, useLocalSearchParams } from "expo-router";
import { isStagingBuild } from "../../lib/app-environment";

export default function PrDeepLinkRoute() {
  const { number } = useLocalSearchParams<{ number: string }>();
  if (!isStagingBuild || !/^\d+$/.test(number)) return <Redirect href="/" />;
  return <Redirect href={{ pathname: "/dev/channels", params: { pr: number } }} />;
}
