import type { ReactNode } from "react";
import { PreviewFingerprint } from "@/components/preview-fingerprint";
import { PreviewNotice } from "@/components/preview-notice";
import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "The One 樂玩吉他 2.0",
  description: "The One：有方向的系統課程、練習與老師陪伴，讓每一步更靠近音樂。",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html
      lang="zh-Hant"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col"><PreviewNotice />{children}<PreviewFingerprint /></body>
    </html>
  );
}
