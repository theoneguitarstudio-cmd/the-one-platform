// Native approved UX replaces the older server-form demo only in Mock Preview.
// Keep mock-http-proof.mjs as historical server-form proof, not a claimed current PASS.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
export async function runUxHttpProof(base = "http://127.0.0.1:8787") {
  if (!["http://127.0.0.1:8787", "https://the-one-platform-preview.theoneguitarstudio.workers.dev"].includes(base)) throw Error("Unapproved UX proof target");
  const results = [];
  const request = (path, options = {}) => fetch(base + path, { ...options, redirect: "manual", signal: AbortSignal.timeout(15000) });
  const routes = ["/", "/teachers/t1?tab=private", "/courses/guitar-roadmap", "/products", "/membership", "/student", "/student/map", "/student/courses/c1/lessons/l1", "/student/private", "/student/feedback", "/account/profile", "/account/membership", "/account/billing", "/account/orders", "/checkout/private_package?teacherId=t1&offerId=p4", "/account/membership/cancel", "/teacher", "/teacher/students", "/teacher/schedule", "/teacher/reviews", "/admin/courses", "/admin/courses/c1", "/admin/review", "/admin/bookings", "/admin/finance", "/auth/sign-in"];
  for (const path of routes) {
    const r = await request(path); const html = await r.text();
    assert.equal(r.status, 200, path); assert.match(html, /Mock 預覽/);
    assert.match(html, /Preview · /); assert.doesNotMatch(html, /<iframe/i);
    assert.ok(r.headers.get("content-security-policy")?.includes("connect-src 'self'"));
    results.push({ path, status: "PASS", kind: "HTTP render; client flows verified separately" });
  }
  for (const path of ["/auth/sign-in", "/admin/courses/c1/edit", "/api/payments/mock/webhook"]) {
    assert.equal((await request(path, { method: "POST", body: "synthetic" })).status, 503);
    results.push({ path, status: "PASS", kind: "write rejected" });
  }
  for (const path of ["/auth/callback", "/auth/confirm", "/lesson/synthetic/join"]) assert.equal((await request(path)).status, 503);
  assert.equal((await request("/missing-preview-page")).status, 404);
  const logo = await request("/brand/the-one-logo.png"); assert.equal(logo.status, 200);
  assert.equal(createHash("sha256").update(Buffer.from(await logo.arrayBuffer())).digest("hex"), "9bedb5ab28fba4490876957f03a5354f4efebbdf8a6e90f2c6133206dccccd43");
  const meta = await (await request("/__preview-meta")).json();
  assert.equal(meta.dataMode, "mock");
  return { results, meta, productionConnections: 0, productionWrites: 0, logo: "original SHA256 match" };
}
