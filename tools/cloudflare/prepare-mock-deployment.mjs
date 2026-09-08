// Build only. This command never deploys or retrieves credentials.
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, readdirSync, mkdirSync } from "node:fs";
const branch = spawnSync("git", ["branch", "--show-current"], { encoding: "utf8", windowsHide: true });
if (branch.status !== 0 || branch.stdout.trim() !== "preview-test") throw new Error("Only preview-test can prepare this Preview");
if (readdirSync(".").some(name => /^\.env(?:\.|$)/.test(name) && name !== ".env.example")) throw new Error("Use a checkout without .env files; never read production settings");
const source = spawnSync("git", ["rev-parse", "HEAD"], { encoding: "utf8", windowsHide: true });
const status = spawnSync("git", ["status", "--porcelain"], { encoding: "utf8", windowsHide: true });
if (source.status !== 0 || status.status !== 0 || !/^[a-f0-9]{40}$/.test(source.stdout.trim())) throw new Error("Cannot identify source build");
const previewSha = source.stdout.trim() + (status.stdout.trim() ? "-dirty" : "");
const vars = { NEXT_PUBLIC_PREVIEW_SHA: previewSha, THE_ONE_ENV: "preview", NEXT_PUBLIC_APP_ENV: "preview", NEXT_PUBLIC_DATA_MODE: "mock", NEXT_PUBLIC_SITE_URL: "https://the-one-platform-preview.theoneguitarstudio.workers.dev" };
const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => /^(PATH|PATHEXT|SystemRoot|WINDIR|COMSPEC|TEMP|TMP|USERPROFILE|LOCALAPPDATA|APPDATA|SYSTEMDRIVE|NUMBER_OF_PROCESSORS)$/i.test(key)));
Object.assign(env, vars, { WRANGLER_SEND_METRICS: "false", CLOUDFLARE_VITE_ENABLE_REMOTE_BINDINGS: "false", CI: "true" });
mkdirSync("artifacts/cloudflare-mock", { recursive: true });
const result = spawnSync(process.execPath, ["node_modules/vinext/dist/cli.js", "build"], { env, encoding: "utf8", windowsHide: true, timeout: 180000 });
writeFileSync("artifacts/cloudflare-mock/deployment-build.log", (result.stdout ?? "") + (result.stderr ?? ""));
if (result.status !== 0) throw new Error("Preview build failed; inspect local deployment-build.log");
const path = "dist/server/wrangler.json";
const config = JSON.parse(readFileSync(path, "utf8"));
if (config.name !== "the-one-platform-preview" || config.routes?.length || config.workers_dev !== true) throw new Error("Wrong Preview target");
for (const key of ["kv_namespaces", "r2_buckets", "d1_databases", "services", "send_email", "workflows", "unsafe", "dispatch_namespaces", "hyperdrive", "containers"]) {
 if (config[key] && Object.keys(config[key]).length) throw new Error("Unexpected binding: " + key);
}
if (config.durable_objects?.bindings?.length || config.queues?.producers?.length || config.queues?.consumers?.length) throw new Error("Unexpected stateful binding");
config.vars = vars;
config.account_id = "611ed099848d669a9f4388998dc20fd0";
writeFileSync(path, JSON.stringify(config, null, 2));
console.log("MOCK_PREVIEW_BUILD_PASS — prepared only; no deployment");
