import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
const refresh = vi.hoisted(() => vi.fn());
vi.mock("@/lib/supabase/proxy", () => ({ refreshSupabaseSession: refresh }));
import { proxy } from "../src/proxy";

describe("approved hosted UX Preview transport", () => {
  beforeEach(() => {
    refresh.mockReset();
    for (const [key, value] of Object.entries({ NODE_ENV: "production", THE_ONE_ENV: "preview", NEXT_PUBLIC_APP_ENV: "preview", NEXT_PUBLIC_DATA_MODE: "mock", NEXT_PUBLIC_SUPABASE_URL: "", NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "" })) vi.stubEnv(key, value);
  });
  afterEach(() => vi.unstubAllEnvs());
  it.each(["/", "/student", "/teacher", "/admin", "/account/billing", "/teachers/t1?tab=private"])("uses native UX with no Auth connection: %s", async path => {
    const response = await proxy(new NextRequest(`https://the-one-platform-preview.theoneguitarstudio.workers.dev${path}`));
    expect(response.headers.get("x-middleware-rewrite")).toContain("/ux-prototype");
    expect(refresh).not.toHaveBeenCalled();
  });
  it.each(["/auth/sign-in", "/admin", "/api/payments/manual/webhook"])("rejects writes: %s", async path => {
    const response = await proxy(new NextRequest(`https://preview.workers.dev${path}`, { method: "POST", body: "synthetic" }));
    expect(response.status).toBe(503);
    expect(refresh).not.toHaveBeenCalled();
  });
  it("keeps read-only health available", async () => {
    expect((await proxy(new NextRequest("https://preview.workers.dev/api/health"))).headers.get("x-middleware-next")).toBe("1");
    expect(refresh).not.toHaveBeenCalled();
  });
  it.each([{ THE_ONE_ENV: "production" }, { NEXT_PUBLIC_APP_ENV: "production" }, { NEXT_PUBLIC_SUPABASE_URL: "https://invalid.example" }])("rejects unsafe mixed environments %j", async values => {
    for (const [key, value] of Object.entries(values)) vi.stubEnv(key, value);
    await expect(proxy(new NextRequest("https://preview.workers.dev/admin"))).rejects.toThrow();
    expect(refresh).not.toHaveBeenCalled();
  });
});
