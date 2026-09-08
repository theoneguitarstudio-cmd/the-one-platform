import { defineConfig } from "vite";
import vinext from "vinext";
import { cloudflare } from "@cloudflare/vite-plugin";
import { assertPreviewEnvironment } from "./tools/cloudflare/environment";
export default defineConfig(() => {
    assertPreviewEnvironment(process.env);
    return { plugins: [vinext(), cloudflare({ viteEnvironment: { name: "rsc", childEnvironments: ["ssr"] } })] };
});
