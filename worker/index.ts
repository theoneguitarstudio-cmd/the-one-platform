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
        const prepared = await bufferFormRequest(args[0]);
        if (prepared instanceof Response)
            return prepared;
        args[0] = prepared;
        return handler.fetch(...args);
    },
};
export default worker;
