import assert from "node:assert/strict";
import { writeFileSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
const base = "http://127.0.0.1:8787";
export async function runHttpProof() {
    const results = [];
    async function check(name, fn) { await fn(); results.push({ name, status: "PASS" }); }
    const request = async (path, options = {}) => {
        const response = await fetch(base + path, { ...options, redirect: "manual", signal: AbortSignal.timeout(15000) });
        // Consume every response, including rejected POSTs, before reusing the connection.
        const body = await response.arrayBuffer();
        return new Response([204, 205, 304].includes(response.status) ? null : body, { status: response.status, headers: response.headers });
    };
    let html, cookie = "";
    await check("homepage SSR", async () => { const r = await request("/"); assert.equal(r.status, 200); assert.match(await r.text(), /Platform Foundation/); });
    await check("health route", async () => { const r = await request("/api/health"); assert.equal(r.status, 200); assert.match(r.headers.get("content-type"), /json/); });
    await check("unauthenticated protected route", async () => { const r = await request("/student"); assert.ok([302, 303, 307].includes(r.status)); assert.match(r.headers.get("location"), /auth\/sign-in/); });
    await check("login HTML and Server Action reference", async () => { const r = await request("/auth/sign-in"); assert.equal(r.status, 200); html = await r.text(); assert.match(html, /\$ACTION_/); });
    const form = () => {
        const f = new FormData();
        for (const tag of html.matchAll(/<input\b[^>]*>/g)) {
            const name = tag[0].match(/name="([^"]*)"/)?.[1];
            if (name?.startsWith("$ACTION_")) {
                const value = tag[0].match(/value="([^"]*)"/)?.[1] ?? "";
                f.set(name, value.replaceAll("&quot;", '"').replaceAll("&amp;", "&"));
            }
        }
        f.set("email", "proof@example.invalid");
        f.set("password", "synthetic-password-only");
        return f;
    };
    await check("cross-origin Server Action rejected", async () => { const r = await request("/auth/sign-in", { method: "POST", headers: { Origin: "https://attacker.invalid" }, body: form() }); assert.equal(r.status, 403); });
    await check("login POST + session Cookie", async () => { const r = await request("/auth/sign-in", { method: "POST", headers: { Origin: base }, body: form() }); assert.equal(r.status, 303, r.status === 303 ? undefined : await r.text()); assert.match(r.headers.get("location"), /student/); const cookies = r.headers.getSetCookie(); assert.ok(cookies.some(c => c.includes("auth-token"))); cookie = cookies.map(c => c.split(";")[0]).join("; "); });
    await check("authenticated SSR and Supabase identity", async () => { const r = await request("/student", { headers: { Cookie: cookie } }); assert.equal(r.status, 200); assert.match(await r.text(), /Student/); });
    await check("Student cannot enter Admin", async () => { const r = await request("/admin", { headers: { Cookie: cookie } }); assert.match(r.headers.get("location"), /access-denied/); });
    await check("proxy refreshes expired session Cookie", async () => {
        const name = cookie.split("=")[0];
        const raw = decodeURIComponent(cookie.split(";")[0].slice(name.length + 1));
        const session = JSON.parse(Buffer.from(raw.replace(/^base64-/, ""), "base64url").toString());
        const parts = session.access_token.split(".");
        const claims = JSON.parse(Buffer.from(parts[1], "base64url").toString());
        claims.exp = Math.floor(Date.now() / 1000) - 60;
        parts[1] = Buffer.from(JSON.stringify(claims)).toString("base64url");
        session.access_token = parts.join(".");
        session.expires_at = claims.exp;
        const expired = name + "=base64-" + Buffer.from(JSON.stringify(session)).toString("base64url");
        const r = await request("/", { headers: { Cookie: expired } });
        assert.equal(r.status, 200);
        assert.ok(r.headers.getSetCookie().some(value => value.includes("auth-token")));
    });
    await check("public teachers + image", async () => { const r = await request("/teachers"); assert.equal(r.status, 200); const text = await r.text(); assert.match(text, /Synthetic Teacher/); assert.match(text, /src="\/next.svg"/); });
    for (const path of ["/teachers/synthetic-teacher", "/products", "/auth/sign-up", "/auth/forgot-password", "/auth/access-denied"])
        await check("public page " + path, async () => assert.equal((await request(path)).status, 200));
    await check("unsupported payment POST stays disabled", async () => { const r = await request("/api/payments/synthetic/webhook", { method: "POST", body: "{}" }); assert.equal(r.status, 501); });
    await check("404", async () => assert.equal((await request("/does-not-exist-proof")).status, 404));
    await check("invalid callback redirects safely", async () => { const r = await request("/auth/callback?next=https://attacker.invalid"); assert.ok([302, 303, 307].includes(r.status)); assert.ok(!r.headers.get("location").includes("attacker.invalid")); });
    await check("static SVG", async () => { const r = await request("/next.svg"); assert.equal(r.status, 200); assert.match(r.headers.get("content-type"), /svg/); });
    const files = [];
    function walk(dir) {
        for (const name of readdirSync(dir)) {
            const file = join(dir, name);
            if (statSync(file).isDirectory())
                walk(file);
            else
                files.push(file);
        }
    }
    walk("dist/client");
    await check("client bundle has no privileged secret or production ref", async () => {
        for (const file of files.filter(f => /\.(js|css|html)$/.test(f))) {
            const content = readFileSync(file, "utf8");
            assert.ok(!content.includes("ygxeihtcolpiulupieeq"));
            assert.ok(!content.includes("SUPABASE_SERVICE_ROLE_KEY"));
        }
    });
    await check("compiled JS and CSS served", async () => {
        for (const ext of [".js", ".css"]) {
            const file = files.find(f => f.endsWith(ext));
            assert.ok(file);
            assert.equal((await request("/" + file.replaceAll("\\", "/").replace(/^dist\/client\//, ""))).status, 200);
        }
    });
    return results;
}
if (process.argv.includes("--standalone")) {
    const results = await runHttpProof();
    writeFileSync("artifacts/cloudflare-local/http-results.json", JSON.stringify({ time: new Date().toISOString(), results }, null, 2));
    console.log(JSON.stringify(results, null, 2));
}
