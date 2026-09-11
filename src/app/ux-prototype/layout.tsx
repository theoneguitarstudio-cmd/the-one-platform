import { notFound } from "next/navigation";
import { PrototypeProvider } from "@/modules/ux-prototype/store";
import { PrototypeTools } from "@/components/ux-prototype/tools";
import { PlatformRoutes } from "@/components/platform-experience/link";
import { ExperienceViewProvider } from "@/modules/platform-experience/view-state";

export const metadata = { title: "The One 2.0｜本機 UX 雛形", robots: { index: false, follow: false } };

export default function PrototypeLayout({ children }: { children: React.ReactNode }) {
  if (process.env.NODE_ENV !== "development") notFound();
  return <PlatformRoutes enabled={process.env.THE_ONE_LOCAL_EXPERIENCE === "1"}><PrototypeProvider><ExperienceViewProvider>{children}<PrototypeTools /></ExperienceViewProvider></PrototypeProvider></PlatformRoutes>;
}
