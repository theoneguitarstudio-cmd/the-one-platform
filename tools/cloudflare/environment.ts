type Environment = Record<string, string | undefined>;
const productionRef = "ygxeihtcolpiulupieeq";
export function assertPreviewEnvironment(env: Environment): void {
    const url = new URL(env.NEXT_PUBLIC_SUPABASE_URL ?? "");
    const site = new URL(env.NEXT_PUBLIC_SITE_URL ?? "");
    if (url.username || url.password || url.pathname !== "/" || url.search || url.hash || site.username || site.password)
        throw new Error("Invalid Preview URL");
    if ((env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "").length < 20)
        throw new Error("Missing Preview public key");
    if (env.THE_ONE_ENV === "local-proof") {
        if (url.origin !== "http://127.0.0.1:54329" || site.origin !== "http://127.0.0.1:8787")
            throw new Error("Local proof must use loopback mocks");
        if (env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY !== "synthetic-local-public-key-only")
            throw new Error("Local proof requires synthetic key");
        if (env.SUPABASE_SERVICE_ROLE_KEY)
            throw new Error("Local proof forbids service credentials");
        return;
    }
    const ref = env.THE_ONE_PREVIEW_SUPABASE_REF ?? "";
    if (env.THE_ONE_ENV !== "preview" || !/^[a-z]{20}$/.test(ref) || ref === productionRef)
        throw new Error("Preview target must be explicitly approved");
    const key = env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "";
    let publicKey = /^sb_publishable_[A-Za-z0-9_-]{20,}$/.test(key);
    if (!publicKey && key.split(".").length === 3) {
        try {
            const payload = JSON.parse(atob(key.split(".")[1].replaceAll("-", "+").replaceAll("_", "/")));
            publicKey = payload.role === "anon" && payload.ref === ref && payload.iss === "supabase";
        }
        catch {
            publicKey = false;
        }
    }
    if (!publicKey)
        throw new Error("Preview requires its public publishable/anon key");
    if (url.origin !== "https://" + ref + ".supabase.co" || site.protocol !== "https:" || !site.hostname.endsWith(".workers.dev"))
        throw new Error("Wrong Preview target or site");
}
