import { spawn, spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync, createWriteStream } from "node:fs";
import { createServer } from "node:net";
import { startMock } from "./mock-supabase.mjs";
import { runHttpProof } from "./http-proof.mjs";
import { runMockHttpProof } from "./mock-http-proof.mjs";
const mockMode = process.argv.includes("--mock");
const output = mockMode ? "artifacts/cloudflare-mock" : "artifacts/cloudflare-local";
mkdirSync(output, { recursive: true });
const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => /^(PATH|PATHEXT|SystemRoot|WINDIR|COMSPEC|TEMP|TMP|USERPROFILE|LOCALAPPDATA|APPDATA|SYSTEMDRIVE|NUMBER_OF_PROCESSORS)$/i.test(key)));
Object.assign(env, { THE_ONE_ENV: "local-proof", NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54329", NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "synthetic-local-public-key-only", NEXT_PUBLIC_SITE_URL: "http://127.0.0.1:8787", WRANGLER_SEND_METRICS: "false", CLOUDFLARE_VITE_ENABLE_REMOTE_BINDINGS: "false", CI: "true" });
if (mockMode) {
 delete env.NEXT_PUBLIC_SUPABASE_URL; delete env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
 Object.assign(env,{ THE_ONE_ENV:"preview",NEXT_PUBLIC_APP_ENV:"preview",NEXT_PUBLIC_DATA_MODE:"mock" });
}
function stop(child) {
    if (!child || child.exitCode !== null)
        return;
    if (process.platform === "win32")
        spawnSync("taskkill", ["/PID", String(child.pid), "/T", "/F"], { windowsHide: true, stdio: "ignore" });
    else
        child.kill("SIGTERM");
}
function launch(file, args, log) {
    const stream = createWriteStream(output + "/" + log);
    const child = spawn(process.execPath, [file, ...args], { env, stdio: ["ignore", "pipe", "pipe"], windowsHide: true });
    child.stdout.pipe(stream);
    child.stderr.pipe(stream);
    return child;
}
async function run(file, args, log) {
    const child = launch(file, args, log);
    const timer = setTimeout(() => stop(child), 180000);
    try {
        await new Promise((resolve, reject) => { child.once("error", reject); child.once("exit", code => code === 0 ? resolve() : reject(new Error(log + " failed: " + code))); });
    }
    finally {
        clearTimeout(timer);
    }
}
// Refuse to test an unrelated service already listening on the proof port.
const probe = createServer();
await new Promise((resolve, reject) => { probe.once("error", reject); probe.listen(8787, "127.0.0.1", () => probe.close(resolve)); });
const mock = mockMode ? null : await startMock();
let worker;
const evidence = { time: new Date().toISOString(), synthetic: true, status: "FAIL", results: [], productionConnections: 0, productionWrites: 0 };
try {
    if (!process.argv.includes("--skip-build"))
        await run("node_modules/vinext/dist/cli.js", ["build"], "build.log");
    writeFileSync("dist/server/.dev.vars", Object.entries(env).filter(([key]) => key.startsWith("THE_ONE_") || key.startsWith("NEXT_PUBLIC_")).map(([key, value]) => key + "=" + value).join("\n") + "\n");
    worker = launch("node_modules/wrangler/bin/wrangler.js", ["dev", "--local", "--config", "dist/server/wrangler.json", "--port", "8787", "--ip", "127.0.0.1"], "worker.log");
    const deadline = Date.now() + 60000;
    while (true) {
        try {
            const response = await fetch("http://127.0.0.1:8787/api/health", { signal: AbortSignal.timeout(1000) });
            await response.arrayBuffer();
            if (response.status === 200)
                break;
        }
        catch { }
        if (Date.now() > deadline)
            throw new Error("Worker startup timeout; inspect local worker.log");
        await new Promise(resolve => setTimeout(resolve, 500));
    }
    console.log("LOCAL_WORKER_READY http://127.0.0.1:8787 — synthetic backend only");
    const repeats = process.argv.includes("--repeat-20") ? 20 : 1;
    for (let i = 0; i < repeats; i++)
        evidence.results = mockMode ? await runMockHttpProof() : await runHttpProof();
    evidence.repetitions = repeats;
    evidence.status = "PASS";
    console.log("HTTP_PROOF_PASS " + evidence.results.length);
    if (process.argv.includes("--serve"))
        await new Promise(resolve => { process.once("SIGINT", resolve); process.once("SIGTERM", resolve); setTimeout(resolve, 15 * 60 * 1000).unref(); });
}
catch (error) {
    evidence.stopReason = error.message;
    throw error;
}
finally {
    writeFileSync(output + "/proof.json", JSON.stringify(evidence, null, 2));
    writeFileSync(output + "/mock-requests.json", JSON.stringify({ synthetic: true, productionConnections: 0, requests: mock?.requests ?? [] }, null, 2));
    await new Promise(resolve => setTimeout(resolve, 200));
    stop(worker);
    mock?.server.closeAllConnections();
    mock?.server.close();
}
