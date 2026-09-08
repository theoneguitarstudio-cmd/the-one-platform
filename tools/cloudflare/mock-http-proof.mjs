import assert from "node:assert/strict";
import { previewUsers, previewPassword } from "../../src/lib/preview/fixtures.ts";
export async function runMockHttpProof(base="http://127.0.0.1:8787") {
 if (!["http://127.0.0.1:8787", "https://the-one-platform-preview.theoneguitarstudio.workers.dev"].includes(base)) throw new Error("Unapproved Mock proof target");
 const results=[];
 const request=(path,options={})=>fetch(base+path,{...options,redirect:"manual",signal:AbortSignal.timeout(15000)});
 async function page(path,cookie="") {const r=await request(path,{headers:{Cookie:cookie}});const text=await r.text();assert.equal(r.status,200,path+" "+text.slice(0,120));assert.match(text,/PREVIEW/);results.push({name:path,status:"PASS"});return text;}
 for(const path of ["/","/auth/sign-in","/auth/sign-up","/auth/forgot-password","/auth/verify-email","/auth/access-denied","/teachers","/teachers/preview-teacher","/products","/products/preview-private-lesson"]) await page(path);
 for(const user of previewUsers){
  const html=await page("/auth/sign-in");const section=[...html.matchAll(/<form\b[^>]*>([\s\S]*?)<\/form>/g)].find(m=>m[1].includes(user.email))?.[1];assert.ok(section);
  const f=new FormData();for(const tag of section.matchAll(/<input\b[^>]*>/g)){const name=tag[0].match(/name="([^"]*)"/)?.[1];const value=tag[0].match(/value="([^"]*)"/)?.[1]??"";if(name)f.set(name,value.replaceAll("&quot;",'"').replaceAll("&amp;","&"));}f.set("email",user.email);f.set("password",previewPassword);f.set("next",user.path);
  const r=await request("/auth/sign-in",{method:"POST",headers:{Origin:base},body:f});assert.equal(r.status,303,await r.text());assert.match(r.headers.get("location"),new RegExp(user.path));const cookie=r.headers.getSetCookie().map(c=>c.split(";")[0]).join("; ");assert.match(cookie,/auth-token/);
  const paths=user.role==="student"?["/student","/student/orders","/student/orders/00000000-0000-4000-8000-000000000201","/student/trial","/student/packages","/student/schedule","/teachers/preview-teacher/trial?intent=00000000-0000-4000-8000-000000000401"]:user.role==="teacher"?["/teacher","/teacher/profile","/teacher/trials","/teacher/packages","/teacher/schedule"]:["/admin","/admin/orders","/admin/orders/00000000-0000-4000-8000-000000000201","/admin/teachers","/admin/trials","/admin/packages","/admin/schedule"];
  for(const path of paths)await page(path,cookie);
  if(user.role==="student"){
   const product=await page("/products/preview-private-lesson",cookie);
   const form=product.match(/<form\b[^>]*>([\s\S]*?)<\/form>/)?.[1];assert.ok(form);
   const checkout=new FormData();for(const tag of form.matchAll(/<input\b[^>]*>/g)){const n=tag[0].match(/name="([^"]*)"/)?.[1];const v=tag[0].match(/value="([^"]*)"/)?.[1]??"";if(n)checkout.set(n,v.replaceAll("&quot;",'"').replaceAll("&amp;","&"));}checkout.set("quantity","1");
   const stopped=await request("/products/preview-private-lesson",{method:"POST",headers:{Origin:base,Cookie:cookie},body:checkout});assert.equal(stopped.status,303);assert.match(stopped.headers.get("location"),/error=checkout_failed/);results.push({name:"checkout refuses mutation",status:"PASS"});
   const csrf=await request("/products/preview-private-lesson",{method:"POST",headers:{Origin:"https://untrusted.invalid",Cookie:cookie},body:checkout});assert.equal(csrf.status,403);results.push({name:"cross-origin action refused",status:"PASS"});
   const denied=await request("/admin",{headers:{Cookie:cookie}});assert.match(denied.headers.get("location"),/access-denied/);results.push({name:"student role boundary",status:"PASS"});}
 }
 assert.equal((await request("/missing-preview-page")).status,404);results.push({name:"404",status:"PASS"});
 assert.equal((await request("/api/payments/mock/webhook",{method:"POST",body:"{}"})).status,501);results.push({name:"payment stays disabled",status:"PASS"});
 return results;
}
