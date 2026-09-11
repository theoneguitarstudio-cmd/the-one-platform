import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest, NextResponse } from "next/server";
import { isLocalExperience } from "../src/modules/platform-experience/local-mode";

const refresh = vi.hoisted(() => vi.fn());
vi.mock("@/lib/supabase/proxy", () => ({ refreshSupabaseSession: refresh }));
import { proxy } from "../src/proxy";

describe("normal routes local experience transport", () => {
  beforeEach(() => {refresh.mockReset();refresh.mockResolvedValue(NextResponse.next());vi.stubEnv("NODE_ENV","development");vi.stubEnv("THE_ONE_LOCAL_EXPERIENCE","1");});
  afterEach(() => vi.unstubAllEnvs());
  it.each(["/", "/auth/sign-in", "/student", "/account/billing", "/admin/courses/c1/edit", "/teachers/t1?tab=private", "/products/example.png", "/student/orders/example.png"])("rewrites %s before any real auth",async path=>{
    const response=await proxy(new NextRequest(`http://127.0.0.1:3100${path}`));
    expect(refresh).not.toHaveBeenCalled();
    const url=new URL(response.headers.get("x-middleware-rewrite")!);
    expect(url.pathname).toBe(`/ux-prototype${path==="/"?"":path.split("?")[0]}`);
    expect(url.search).toBe(path.includes("?")?`?${path.split("?")[1]}`:"");
    expect(response.headers.get("Content-Security-Policy")).toContain("connect-src 'self'");
  });
  it.each(["/api/payments/manual/webhook", "/auth/callback", "/auth/confirm", "/lesson/123/join"])("cannot execute a real service at %s", async path=>{
    const response=await proxy(new NextRequest(`http://localhost:3100${path}`));
    expect(response.status).toBe(503);expect(refresh).not.toHaveBeenCalled();
  });
  it("rejects POST even to otherwise supported Auth routes",async()=>{
    const response=await proxy(new NextRequest("http://localhost:3100/auth/sign-in",{method:"POST",body:"local test"}));
    expect(response.status).toBe(503);expect(refresh).not.toHaveBeenCalled();
  });
  it.each(["production","test"])("does not bypass production routes in %s with the flag enabled",async mode=>{
    vi.stubEnv("NODE_ENV",mode);
    await proxy(new NextRequest("http://127.0.0.1:3100/admin"));
    expect(refresh).toHaveBeenCalledOnce();
  });
  it("does not enable local transport for a remote hostname",async()=>{
    const response = await proxy(new NextRequest("https://preview.example.test/admin"));
    expect(response.status).toBe(503);
    expect(refresh).not.toHaveBeenCalled();
    expect(isLocalExperience("development","1","localhost.example.test")).toBe(false);
  });
  it("requires the explicit server flag",async()=>{
    vi.stubEnv("THE_ONE_LOCAL_EXPERIENCE","");
    await proxy(new NextRequest("http://localhost:3100/admin"));
    expect(refresh).toHaveBeenCalledOnce();
  });
});
