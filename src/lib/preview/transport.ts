import { isMockDataMode } from "./mode";
import { previewPassword, previewTables, previewUsers } from "./fixtures";
const encode=(value:unknown)=>btoa(JSON.stringify(value)).replaceAll("+","-").replaceAll("/","_").replace(/=+$/,"");
function demoUser(id:string) { const u=previewUsers.find(u=>u.id===id); return u ? {id:u.id,email:u.email,aud:"authenticated",role:"authenticated",app_metadata:{},user_metadata:{display_name:u.name},created_at:"2026-09-01T00:00:00Z"}:null; }
function subject(headers:Headers) {try {const token=headers.get("authorization")?.replace(/^Bearer /,"")??"";return JSON.parse(atob(token.split(".")[1].replaceAll("-","+").replaceAll("_","/"))).sub as string;}catch{return "";} }
const readRpcs=new Set(["get_own_payment_summaries","get_own_scheduling_bookings","get_teacher_scheduling_bookings","get_own_recurring_lesson_series","get_teacher_recurring_lesson_series","get_teacher_availability_configuration","get_available_flexible_slots","get_admin_schedule_overview"]);
export const previewFetch: typeof fetch = async (input,init) => {
  if(!isMockDataMode()) throw new Error("Mock transport cannot run outside explicit Preview mock mode");
  const request=new Request(input,init);const url=new URL(request.url);
  if(url.origin!=="https://preview.invalid") throw new Error("Mock transport refuses external targets");
  const json=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers:{"content-type":"application/json"}});
  const denied=()=>json({code:"PREVIEW_ONLY",message:"Preview only: changes and external services are disabled."},403);
  if(url.pathname==="/auth/v1/token" && request.method==="POST") {
    const body=await request.json() as Record<string,string>;
    const u=body.refresh_token ? previewUsers.find(u=>body.refresh_token==="preview-refresh-"+u.id) : previewUsers.find(u=>u.email===body.email && body.password===previewPassword);
    if(!u)return json({error:"invalid_grant",error_description:"Use a Preview demo identity only"},400);
    const exp=Math.floor(Date.now()/1000)+3600;
    return json({access_token:encode({alg:"HS256",typ:"JWT"})+"."+encode({sub:u.id,aud:"authenticated",exp,role:"authenticated"})+".preview-not-a-real-signature",refresh_token:"preview-refresh-"+u.id,expires_in:3600,token_type:"bearer",user:demoUser(u.id)});
  }
  if(url.pathname==="/auth/v1/user" && request.method==="GET") {const user=demoUser(subject(request.headers));return user?json(user):json({message:"Preview session missing"},401);}
  if(url.pathname==="/auth/v1/logout")return json({});
  if(url.pathname==="/rest/v1/rpc/get_trial_teacher_context") return json(previewTables.teacher_public_profiles.map(row=>({...row,teacher_timezone:"Asia/Taipei"})));
  if(url.pathname.startsWith("/rest/v1/rpc/"))return readRpcs.has(url.pathname.split("/").pop()??"")?json([]):denied();
  if(request.method!=="GET" || !url.pathname.startsWith("/rest/v1/"))return denied();
  const table=url.pathname.split("/").pop()??"";
  let rows=previewTables[table]??[];
  for(const [key,value] of url.searchParams){if(value.startsWith("eq."))rows=rows.filter(row=>String(row[key])===value.slice(3));}
  // Synthetic isolation still avoids showing the demo student's rows as another role.
  if(table==="orders" && subject(request.headers) && subject(request.headers)!==previewUsers[2].id)rows=rows.filter(row=>row.buyer_user_id===subject(request.headers));
  if(request.headers.get("accept")?.includes("application/vnd.pgrst.object+json"))return json(rows[0]??null);
  return json(rows);
};
export function supabaseTransportOptions() {return isMockDataMode()?{global:{fetch:previewFetch}}:{};}
