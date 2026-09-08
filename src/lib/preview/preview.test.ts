import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { isMockDataMode } from "./mode";
import { previewFetch } from "./transport";
import { previewTables, previewPassword } from "./fixtures";
import { assertPreviewEnvironment } from "../../../tools/cloudflare/environment";
const safe={THE_ONE_ENV:"preview",NEXT_PUBLIC_APP_ENV:"preview",NEXT_PUBLIC_DATA_MODE:"mock",NEXT_PUBLIC_SITE_URL:"http://127.0.0.1:8787"};
beforeEach(()=>{for(const [k,v] of Object.entries(safe))vi.stubEnv(k,v);vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL",undefined);vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",undefined);vi.stubGlobal("fetch",vi.fn(()=>{throw new Error("External network forbidden");}));});
afterEach(()=>{vi.unstubAllEnvs();vi.unstubAllGlobals();});
describe("Preview mock isolation",()=>{
 it("is opt-in, no missing-config fallback",()=>{expect(isMockDataMode({})).toBe(false);expect(isMockDataMode(safe)).toBe(true);expect(()=>assertPreviewEnvironment({THE_ONE_ENV:"preview"})).toThrow();expect(()=>assertPreviewEnvironment(safe)).not.toThrow();});
 it.each([{...safe,THE_ONE_ENV:"production"},{...safe,NEXT_PUBLIC_APP_ENV:"production"},{...safe,NEXT_PUBLIC_APP_ENV:"unknown"},{...safe,NEXT_PUBLIC_DATA_MODE:"unknown"},{...safe,NEXT_PUBLIC_SUPABASE_URL:"https://production.invalid"},{...safe,NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:"not-allowed"},{...safe,SUPABASE_SERVICE_ROLE_KEY:"not-allowed"}])("rejects unsafe environment %#",env=>expect(()=>assertPreviewEnvironment(env)).toThrow());
 it("never sends an external target",async()=>{await expect(previewFetch("https://example.com/rest/v1/orders")).rejects.toThrow();expect(fetch).not.toHaveBeenCalled();});
 it("blocks unknown data mode at the transport",async()=>{vi.stubEnv("NEXT_PUBLIC_DATA_MODE","supabase");await expect(previewFetch("https://preview.invalid/rest/v1/orders")).rejects.toThrow();});
 it("returns synthetic products through no-network transport",async()=>{const r=await previewFetch("https://preview.invalid/rest/v1/product_public_catalog");expect((await r.json())[0].name).toContain("Preview");expect(fetch).not.toHaveBeenCalled();});
 it("issues only known demo sessions",async()=>{const r=await previewFetch("https://preview.invalid/auth/v1/token",{method:"POST",body:JSON.stringify({email:"teacher@example.invalid",password:previewPassword})});expect(r.status).toBe(200);const bad=await previewFetch("https://preview.invalid/auth/v1/token",{method:"POST",body:JSON.stringify({email:"real@example.invalid",password:previewPassword})});expect(bad.status).toBe(400);expect(fetch).not.toHaveBeenCalled();});
 it.each(["/rest/v1/orders","/rest/v1/rpc/create_checkout_order","/rest/v1/rpc/create_lesson_booking","/auth/v1/signup","/auth/v1/recover","/auth/v1/user"])("blocks mutations and messages %s",async path=>{const before=JSON.stringify(previewTables);const r=await previewFetch("https://preview.invalid"+path,{method:"POST",body:"{}"});expect(r.status).toBe(403);expect(JSON.stringify(previewTables)).toBe(before);expect(fetch).not.toHaveBeenCalled();});
 it.each(["PATCH","DELETE"])("blocks direct %s",async method=>{expect((await previewFetch("https://preview.invalid/rest/v1/teacher_profiles",{method})).status).toBe(403);});
});
