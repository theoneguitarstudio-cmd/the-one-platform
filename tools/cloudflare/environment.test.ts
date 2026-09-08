import { describe, it, expect } from "vitest";
import { assertPreviewEnvironment } from "./environment";
const local = { THE_ONE_ENV: "local-proof", NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54329", NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "synthetic-local-public-key-only", NEXT_PUBLIC_SITE_URL: "http://127.0.0.1:8787" };
const preview = { THE_ONE_ENV: "preview", THE_ONE_PREVIEW_SUPABASE_REF: "abcdefghijklmnopqrst", NEXT_PUBLIC_SUPABASE_URL: "https://abcdefghijklmnopqrst.supabase.co", NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_synthetic_preview_key_only", NEXT_PUBLIC_SITE_URL: "https://the-one-preview.example.workers.dev" };
describe("Cloudflare Preview isolation", () => {
    it("accepts explicit local mock and matched isolated Preview", () => { expect(() => assertPreviewEnvironment(local)).not.toThrow(); expect(() => assertPreviewEnvironment(preview)).not.toThrow(); });
    it.each([
        { ...preview, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_secret_never_allowed_in_public_env" },
        { ...preview, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.synthetic" },
        {}, { ...local, THE_ONE_ENV: "production" }, { ...local, SUPABASE_SERVICE_ROLE_KEY: "should-never-be-loaded" },
        { ...local, NEXT_PUBLIC_SUPABASE_URL: "https://ygxeihtcolpiulupieeq.supabase.co" },
        { ...preview, THE_ONE_PREVIEW_SUPABASE_REF: "ygxeihtcolpiulupieeq", NEXT_PUBLIC_SUPABASE_URL: "https://ygxeihtcolpiulupieeq.supabase.co" },
        { ...preview, NEXT_PUBLIC_SUPABASE_URL: "https://differenttargetxxxxx.supabase.co" },
        { ...preview, NEXT_PUBLIC_SITE_URL: "https://theoneguitar.com" },
        { ...preview, NEXT_PUBLIC_SUPABASE_URL: "https://user:password@abcdefghijklmnopqrst.supabase.co" },
        { ...preview, NEXT_PUBLIC_SUPABASE_URL: preview.NEXT_PUBLIC_SUPABASE_URL + "/evil" },
        { ...local, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "not-a-local-test-key" },
    ])("fails closed for unsafe/missing environment %#", value => expect(() => assertPreviewEnvironment(value)).toThrow());
});
