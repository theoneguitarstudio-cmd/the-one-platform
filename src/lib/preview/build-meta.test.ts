import { afterEach, describe, expect, it, vi } from "vitest";
import { previewBuildMeta } from "./build-meta";
afterEach(() => vi.unstubAllEnvs());
function mock() { vi.stubEnv("NEXT_PUBLIC_DATA_MODE","mock"); vi.stubEnv("NEXT_PUBLIC_APP_ENV","preview"); vi.stubEnv("THE_ONE_ENV","preview"); }
describe("Preview build fingerprint", () => {
  it("does not expose metadata outside Mock",()=>{vi.stubEnv("NEXT_PUBLIC_DATA_MODE", "supabase");expect(previewBuildMeta()).toBeNull();});
  it("exposes only the validated public source identity",()=>{mock();vi.stubEnv("NEXT_PUBLIC_PREVIEW_SHA","a".repeat(40));expect(previewBuildMeta()?.shortSha).toBe("aaaaaaa");expect(Object.keys(previewBuildMeta()!)).toEqual(["application","environment","dataMode","sha","shortSha"]);});
  it("marks dirty builds visibly",()=>{mock();vi.stubEnv("NEXT_PUBLIC_PREVIEW_SHA","a".repeat(40)+"-dirty");expect(previewBuildMeta()?.shortSha).toBe("aaaaaaa-dirty");});
  it("never reflects arbitrary environment content",()=>{mock();vi.stubEnv("NEXT_PUBLIC_PREVIEW_SHA","invalid-not-a-sha");expect(previewBuildMeta()?.sha).toBe("unavailable");});
});
