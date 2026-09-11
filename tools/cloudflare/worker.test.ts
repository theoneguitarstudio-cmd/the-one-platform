import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";
const delegate = vi.hoisted(() => vi.fn(async () => new Response("delegated")));
vi.mock("vinext/server/fetch-handler", () => ({ default: { fetch: delegate } }));
import worker from "../../worker/index";
const safe = { THE_ONE_ENV: "local-proof", NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54329", NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "synthetic-local-public-key-only", NEXT_PUBLIC_SITE_URL: "http://127.0.0.1:8787" };
beforeEach(() => {
    vi.clearAllMocks();
    for (const [key, value] of Object.entries(safe))
        vi.stubEnv(key, value);
});
afterEach(() => vi.unstubAllEnvs());
describe("Worker entry fail closed", () => {
    it("rejects Mock writes before vinext and form parsing", async () => {
        const mock = { THE_ONE_ENV: "preview", NEXT_PUBLIC_APP_ENV: "preview", NEXT_PUBLIC_DATA_MODE: "mock", NEXT_PUBLIC_SITE_URL: "http://127.0.0.1:8787" };
        vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", undefined); vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", undefined);
        for (const [key, value] of Object.entries(mock)) vi.stubEnv(key, value);
        for (const method of ["POST", "PUT", "PATCH", "DELETE"]) {
            const response = await worker.fetch(new Request("http://127.0.0.1:8787/admin", { method, body: "synthetic" }), mock, {});
            expect(response.status).toBe(503);
        }
        expect(delegate).not.toHaveBeenCalled();
    });
    it("delegates only a verified environment", async () => { expect((await worker.fetch(new Request("http://127.0.0.1:8787"), safe, {})).status).toBe(200); expect(delegate).toHaveBeenCalledOnce(); });
    it("rejects unsafe runtime before application", async () => { expect((await worker.fetch(new Request("http://127.0.0.1:8787"), { ...safe, THE_ONE_ENV: "production" }, {})).status).toBe(503); expect(delegate).not.toHaveBeenCalled(); });
    it("rejects a build/runtime mismatch before application", async () => { vi.stubEnv("NEXT_PUBLIC_SITE_URL", "http://127.0.0.1:3000"); expect((await worker.fetch(new Request("http://127.0.0.1:8787"), safe, {})).status).toBe(503); expect(delegate).not.toHaveBeenCalled(); });
});
