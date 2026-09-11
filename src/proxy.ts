import { NextResponse, type NextRequest } from "next/server";

import { refreshSupabaseSession } from "@/lib/supabase/proxy";
import { isLocalExperience } from "@/modules/platform-experience/local-mode";

function localHeaders(response: NextResponse) {
  response.headers.set("Cache-Control", "no-store");
  response.headers.set("X-Robots-Tag", "noindex, nofollow");
  response.headers.set("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' blob:; font-src 'self'; connect-src 'self' ws://localhost:* ws://127.0.0.1:*; frame-src 'none'; object-src 'none'; base-uri 'self'; form-action 'none'");
  return response;
}

export async function proxy(request: NextRequest) {
  if (process.env.NODE_ENV === "development" && process.env.THE_ONE_LOCAL_EXPERIENCE === "1" && !isLocalExperience(process.env.NODE_ENV, process.env.THE_ONE_LOCAL_EXPERIENCE, request.nextUrl.hostname)) {
    return localHeaders(new NextResponse("本機體驗只接受 localhost。", { status: 503 }));
  }
  if (isLocalExperience(process.env.NODE_ENV, process.env.THE_ONE_LOCAL_EXPERIENCE, request.nextUrl.hostname)) {
    const path = request.nextUrl.pathname;
    if (path.startsWith("/_next/")) return NextResponse.next();
    if (!["GET", "HEAD"].includes(request.method) || path.startsWith("/api/") || /^\/lesson\/[^/]+\/join$/.test(path) || ["/auth/callback", "/auth/confirm"].includes(path)) {
      return localHeaders(new NextResponse("此本機體驗未連接正式服務。", { status: 503 }));
    }
    if (path === "/ux-prototype" || path.startsWith("/ux-prototype/")) return localHeaders(NextResponse.next());
    const destination = request.nextUrl.clone();
    destination.pathname = `/ux-prototype${path === "/" ? "" : path}`;
    return localHeaders(NextResponse.rewrite(destination));
  }
  // The local UX prototype must never initialize a real Auth or database session.
  if (request.nextUrl.pathname === "/ux-prototype" || request.nextUrl.pathname.startsWith("/ux-prototype/")) {
    if (process.env.NODE_ENV !== "development") {
      return new NextResponse("Not found", { status: 404 });
    }
    return localHeaders(NextResponse.next());
  }
  return refreshSupabaseSession(request);
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|brand/|ux-prototype/(?:guitar\\.jpg|wide\\.jpg|student\\.jpg|mobile\\.png|lesson\\.jpg)$).*)",
  ],
};
