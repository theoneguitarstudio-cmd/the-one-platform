import { createServer } from "node:http";
const user = { id: "00000000-0000-4000-8000-000000000001", aud: "authenticated", role: "authenticated", email: "proof@example.invalid", app_metadata: {}, user_metadata: {}, created_at: "2026-01-01T00:00:00Z" };
export async function startMock() {
    const requests = [];
    const server = createServer(async (req, res) => {
        const url = new URL(req.url, "http://127.0.0.1:54329");
        requests.push({ method: req.method, path: url.pathname }); // Never record headers, bodies, cookies, or tokens.
        const send = (value, status = 200) => { res.writeHead(status, { "Content-Type": "application/json" }); res.end(JSON.stringify(value)); };
        if (url.pathname === "/auth/v1/token") {
            let body = "";
            for await (const chunk of req)
                body += chunk;
            const input = JSON.parse(body || "{}");
            if (input.email && input.email !== user.email)
                return send({ error: "invalid_grant", error_description: "Synthetic login rejected" }, 400);
            const encode = value => Buffer.from(JSON.stringify(value)).toString("base64url");
            const token = encode({ alg: "HS256", typ: "JWT" }) + "." + encode({ sub: user.id, aud: "authenticated", exp: Math.floor(Date.now() / 1000) + 3600, role: "authenticated" }) + ".synthetic";
            return send({ access_token: token, refresh_token: "synthetic-refresh-only", expires_in: 3600, token_type: "bearer", user });
        }
        if (url.pathname === "/auth/v1/user")
            return send(user);
        if (url.pathname === "/auth/v1/logout")
            return send({});
        if (url.pathname === "/rest/v1/profiles")
            return send({ account_status: "active" });
        if (url.pathname === "/rest/v1/user_roles")
            return send([{ role: "student" }]);
        if (url.pathname === "/rest/v1/teacher_public_profiles")
            return send([{ teacher_profile_id: user.id, public_slug: "synthetic-teacher", display_name: "Synthetic Teacher", avatar_url: "/next.svg", bio: "Local compatibility proof only", years_experience: 1, teaching_modes: ["online"], trial_price_twd: null, fixed_lesson_price_twd: null, flexible_lesson_price_twd: null, location_text: null }]);
        if (req.method === "GET" && url.pathname.startsWith("/rest/v1/"))
            return send([]);
        return send({ error: "Unmodelled mock request" }, 501);
    });
    await new Promise((resolve, reject) => { server.once("error", reject); server.listen(54329, "127.0.0.1", resolve); });
    return { server, requests };
}
