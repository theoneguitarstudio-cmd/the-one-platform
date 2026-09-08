import { describe, it, expect, vi } from "vitest";
import { bufferFormRequest } from "./form-request";
function post(body: string | Uint8Array<ArrayBuffer>) { return new Request("http://localhost/auth/sign-in", { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded", origin: "http://localhost" }, body }); }
describe("bounded Worker form transport", () => {
    it("preserves method, URL, headers and exact form bytes", async () => { const r = await bufferFormRequest(post("email=proof%40example.invalid&password=synthetic")); expect(r).toBeInstanceOf(Request); const request = r as Request; expect(request.method).toBe("POST"); expect(request.url).toBe("http://localhost/auth/sign-in"); expect(request.headers.get("origin")).toBe("http://localhost"); expect(await request.text()).toBe("email=proof%40example.invalid&password=synthetic"); });
    it("preserves multipart fields", async () => { const f = new FormData(); f.set("$ACTION_ID_synthetic", "value"); const r = await bufferFormRequest(new Request("http://localhost", { method: "POST", body: f })); expect((await (r as Request).formData()).get("$ACTION_ID_synthetic")).toBe("value"); });
    it("accepts exactly 1 MiB", async () => { const r = await bufferFormRequest(post(new Uint8Array(1024 * 1024))); expect(r).toBeInstanceOf(Request); expect((await (r as Request).arrayBuffer()).byteLength).toBe(1024 * 1024); });
    it("rejects oversize forms without delegation", async () => { const r = await bufferFormRequest(post(new Uint8Array(1024 * 1024 + 1))); expect((r as Response).status).toBe(413); });
    it("does not buffer JSON webhooks or GET", async () => { for (const r of [new Request("http://localhost"), new Request("http://localhost", { method: "POST", headers: { "content-type": "application/json" }, body: "{}" })])
        expect(await bufferFormRequest(r)).toBe(r); });
    it("fails closed on broken body", async () => { const stream = new ReadableStream({ start(c) { c.error(new Error("synthetic")); } }); const request = new Request("http://localhost", { method: "POST", headers: { "content-type": "multipart/form-data; boundary=x" }, body: stream, duplex: "half" } as RequestInit); expect((await bufferFormRequest(request) as Response).status).toBe(400); });
    it("times out a stalled form", async () => { vi.useFakeTimers(); try {
        const stream = new ReadableStream();
        const request = new Request("http://localhost", { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body: stream, duplex: "half" } as RequestInit);
        const result = bufferFormRequest(request);
        await vi.advanceTimersByTimeAsync(10001);
        expect((await result as Response).status).toBe(408);
    }
    finally {
        vi.useRealTimers();
    } });
});
