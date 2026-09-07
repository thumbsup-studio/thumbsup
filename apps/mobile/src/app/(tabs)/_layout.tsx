import { tokens } from "@thumbsup/tokens";
import { Tabs } from "expo-router";
import { CourseIcon, HistoryIcon, HomeIcon, UserIcon } from "../../components/icons";

export default function TabsLayout() {
  return (
    <Tabs
      backBehavior="history"
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: tokens.color.primary,
        tabBarHideOnKeyboard: true,
        tabBarLabelStyle: { fontSize: 12, fontWeight: "600" },
        tabBarStyle: { minHeight: 64, paddingBottom: 8, paddingTop: 6 },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          tabBarIcon: ({ color, size }) => <HomeIcon color={color} height={size} width={size} />,
          title: "홈",
        }}
      />
      <Tabs.Screen
        name="course"
        options={{
          tabBarIcon: ({ color, size }) => <CourseIcon color={color} height={size} width={size} />,
          title: "코스",
        }}
      />
      <Tabs.Screen
        name="history"
        options={{
          tabBarIcon: ({ color, size }) => <HistoryIcon color={color} height={size} width={size} />,
          title: "히스토리",
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          tabBarIcon: ({ color, size }) => <UserIcon color={color} height={size} width={size} />,
          title: "프로필",
        }}
      />
    </Tabs>
  );
}
