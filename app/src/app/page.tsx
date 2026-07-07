import { HomePage } from "@/features/home/components/home-page";
import { mockHomeData } from "@/features/home/mock-home-data";

export default function Home() {
  return <HomePage data={mockHomeData} now={new Date().toISOString()} />;
}
