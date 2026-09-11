import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest, NextResponse } from "next/server";

const refresh = vi.hoisted(() => vi.fn());
vi.mock("@/lib/supabase/proxy", () => ({ refreshSupabaseSession: refresh }));
import { proxy } from "../src/proxy";

describe("local UX prototype isolation", () => {
  beforeEach(() => { refresh.mockReset(); refresh.mockResolvedValue(NextResponse.next()); });
  afterEach(() => vi.unstubAllEnvs());
  it.each(["/ux-prototype", "/ux-prototype/student", "/ux-prototype/admin/courses/c1/edit"])("never touches real auth for development %s", async path => {
    vi.stubEnv("NODE_ENV", "development");
    const response = await proxy(new NextRequest(`http://localhost:3000${path}`));
    expect(refresh).not.toHaveBeenCalled();
    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Security-Policy")).toContain("frame-src 'none'");
    expect(response.headers.get("Cache-Control")).toBe("no-store");
  });
  it("fails closed in production without querying auth", async () => {
    vi.stubEnv("NODE_ENV", "production");
    const response = await proxy(new NextRequest("http://localhost:3000/ux-prototype/admin"));
    expect(response.status).toBe(404);
    expect(refresh).not.toHaveBeenCalled();
  });
  it.each(["/student", "/admin", "/teacher", "/ux-prototype-other"])("preserves existing auth for %s", async path => {
    vi.stubEnv("NODE_ENV", "development");
    await proxy(new NextRequest(`http://localhost:3000${path}`));
    expect(refresh).toHaveBeenCalledOnce();
  });
});
