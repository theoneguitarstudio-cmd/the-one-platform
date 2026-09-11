import { previewBuildMeta } from "../src/lib/preview/build-meta";
import handler from "vinext/server/fetch-handler";
import { assertPreviewEnvironment } from "../tools/cloudflare/environment";
import { bufferFormRequest } from "../tools/cloudflare/form-request";
const worker = {
    async fetch(...args: Parameters<typeof handler.fetch>) {
        const [, env] = args;
        try {
            assertPreviewEnvironment(env as Record<string, string | undefined>);
            // Public values are baked into the client/server build. Reject mixed artifacts.
            if (env.NEXT_PUBLIC_DATA_MODE !== process.env.NEXT_PUBLIC_DATA_MODE || env.NEXT_PUBLIC_APP_ENV !== process.env.NEXT_PUBLIC_APP_ENV || env.NEXT_PUBLIC_SUPABASE_URL !== process.env.NEXT_PUBLIC_SUPABASE_URL ||
                env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY !== process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
                env.NEXT_PUBLIC_SITE_URL !== process.env.NEXT_PUBLIC_SITE_URL)
                throw new Error("Build/runtime mismatch");
        }
        catch {
            return new Response("Preview environment is not configured safely.", { status: 503 });
        }
        if (new URL(args[0].url).pathname === "/__preview-meta") {
            const meta = previewBuildMeta();
            if (!meta) return new Response("Not found", { status: 404 });
            if (args[0].method !== "GET") return new Response("Method not allowed", { status: 405 });
            return Response.json(meta, { headers: { "Cache-Control": "no-store" } });
        }
        // Drain bounded request bodies before rejection to avoid the local proxy stream race.
        const prepared = await bufferFormRequest(args[0], env.NEXT_PUBLIC_DATA_MODE === "mock");
        if (prepared instanceof Response) return prepared;
        // Mock UX never submits a server action, even before vinext parses it.
        if (env.NEXT_PUBLIC_DATA_MODE === "mock" && !["GET", "HEAD"].includes(args[0].method)) {
            return new Response("UX Preview does not accept writes.", { status: 503, headers: { "Cache-Control": "no-store" } });
        }
        args[0] = prepared;
        return handler.fetch(...args);
    },
};
export default worker;
