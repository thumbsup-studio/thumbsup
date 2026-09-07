import { Redirect } from "expo-router";
import { isStagingBuild } from "../../lib/app-environment";

const StagingChannelScreen = isStagingBuild
  ? require("../../features/dev-channels/channel-list-screen").default
  : null;

export default function DevChannelsRoute() {
  if (!StagingChannelScreen) return <Redirect href="/" />;
  return <StagingChannelScreen />;
}
