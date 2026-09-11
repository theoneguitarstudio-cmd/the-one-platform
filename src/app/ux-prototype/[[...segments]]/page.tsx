import { PrototypePage } from "@/components/ux-prototype/page";
import { Suspense } from "react";
import { notFound } from "next/navigation";

export default async function Page({ params }: { params: Promise<{ segments?: string[] }> }) {
  const { segments = [] } = await params;
  if (segments.length && !["student","teacher","admin","account","notifications","search","products","system-courses","membership","checkout","onboarding","faq","about","support","help","legal","auth","unavailable","error","teachers","courses","articles","policies","diagnosis"].includes(segments[0])) notFound();
  return <Suspense fallback={<p role="status">正在開啟本機 UX 預覽…</p>}><PrototypePage segments={segments} /></Suspense>;
}
