import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { AppChrome } from "@/components/app-chrome";
import "./globals.css";

const fontSans = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-sans",
});

export const metadata: Metadata = {
  title: "AgriLink · CAP",
  description: "AgriLink — the web home for the Collective Action Program: community feed, farm directory, cohort resources, and staff tools.",
  icons: {
    apple: "/icon.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={fontSans.variable}>
      <body>
        <AppChrome>{children}</AppChrome>
      </body>
    </html>
  );
}
