import { AsyncLocalStorage } from "node:async_hooks";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

// Import the actual exported config, but never load the Auth transport.
vi.mock("@/lib/supabase/proxy", () => ({
  refreshSupabaseSession: () => { throw new Error("Matcher tests must not invoke Auth."); },
}));
import { config } from "../src/proxy";

// This installed Next release still exports the Middleware-named utility.
// Exercise Next's compiled matcher, not a hand-written equivalent RegExp.
let matches: typeof import("next/experimental/testing/server").unstable_doesMiddlewareMatch;
beforeAll(async () => {
  vi.stubGlobal("AsyncLocalStorage", AsyncLocalStorage);
  matches = (await import("next/experimental/testing/server")).unstable_doesMiddlewareMatch;
});
afterAll(() => vi.unstubAllGlobals());

describe("platform experience actual Next matcher", () => {
  it.each([
    "/",
    "/products/example.png",
    "/teachers/example.svg",
    "/student/orders/example.jpeg",
    "/student/orders/example.png?_rsc=local-navigation",
    "/admin/orders/example.webp",
    "/teacher/schedule",
    "/api/payments/provider.png/webhook",
    "/lesson/example.png/join",
    "/auth/callback?code=synthetic",
    "/ux-prototype/student/example.png",
    "/brandish/example.png",
  ])("runs isolation before dynamic/service route %s", url => {
    expect(matches({ config, nextConfig: {}, url })).toBe(true);
  });

  it.each([
    "/_next/static/chunks/app.js",
    "/_next/image?url=%2Fbrand%2Flogo.png&w=256&q=75",
    "/favicon.ico",
    "/brand/the-one-logo.png",
    "/ux-prototype/guitar.jpg",
    "/ux-prototype/mobile.png",
  ])("leaves known static asset %s outside the rewrite", url => {
    expect(matches({ config, nextConfig: {}, url })).toBe(false);
  });

  it("does not treat an asset filename followed by a route suffix as the asset itself", () => {
    expect(matches({ config, nextConfig: {}, url: "/ux-prototype/guitar.jpg/student" })).toBe(true);
  });
});
