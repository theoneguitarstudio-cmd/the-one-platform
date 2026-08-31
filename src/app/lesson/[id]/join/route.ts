import { NextResponse } from "next/server";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { getAuthenticatedIdentity } from "@/modules/auth/session";
import { normalizeMeetingUrl } from "@/modules/trials/meeting-url";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const identity = await getAuthenticatedIdentity();
  if (!identity || identity.accountStatus !== "active") {
    const signIn = new URL("/auth/sign-in", request.url);
    signIn.searchParams.set("next", new URL(request.url).pathname);
    return NextResponse.redirect(signIn);
  }
  const { id } = await params;
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("lessons")
    .select("meeting_provider, meeting_url, status, delivery_mode")
    .eq("id", id)
    .maybeSingle();
  if (error || !data || data.status !== "scheduled" || data.delivery_mode !== "online" || !data.meeting_url) {
    return NextResponse.redirect(new URL("/auth/access-denied", request.url));
  }
  const meetingUrl = normalizeMeetingUrl(data.meeting_provider, data.meeting_url);
  if (!meetingUrl) {
    return NextResponse.redirect(new URL("/auth/access-denied", request.url));
  }
  return NextResponse.redirect(meetingUrl);
}
