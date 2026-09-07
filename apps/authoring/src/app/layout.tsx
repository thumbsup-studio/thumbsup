import { AppToastProvider } from "@thumbsup/ui-web";
import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";

const pretendard = localFont({
  src: "../../../../packages/ui-web/assets/PretendardVariable.woff2",
  variable: "--font-pretendard",
  display: "swap",
  weight: "45 920",
});

export const metadata: Metadata = {
  title: "문제 저작 · Thumbs Up",
  description: "Thumbs Up 문제 생성·검수·승인 도구",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html className={`${pretendard.variable} h-full antialiased`} lang="ko">
      <body className="flex min-h-full flex-col">
        <AppToastProvider>{children}</AppToastProvider>
      </body>
    </html>
  );
}
