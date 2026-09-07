import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {open,record} from './pg-local.mjs';
import {compileCase} from './compile.mjs';
import {observe} from './pg-cases.mjs';
import {reconcile} from './observe.mjs';
import {hash,candidate} from './schema.mjs';
function source(name,stack=[]){if(!/^[a-z0-9_.-]+\.sql$/.test(name)||stack.includes(name))throw Error('INCLUDE');return readFileSync('supabase/tests/database/'+name,'utf8').replace(/^\\ir\s+([a-z0-9_.-]+\.sql)\s*$/gm,(_,n)=>source(n,[...stack,name]));}
// PostgreSQL lexical splitter: quoted strings/identifiers, dollar bodies and nested comments.
export function directives(sql){
 const vars=new Set(),stack=[];let active=true;const out=[];
 for(const line of sql.split(/\r?\n/)){if(!line.startsWith("\\")){if(active)out.push(line);continue;}
 let m;if((m=line.match(/^\\set (\w+) true$/))){if(active)vars.add(m[1]);}
 else if((m=line.match(/^\\unset (\w+)$/))){if(active)vars.delete(m[1]);}
 else if((m=line.match(/^\\if :\{\?(\w+)\}$/))){stack.push({parent:active,condition:vars.has(m[1])});active=active&&vars.has(m[1]);}
 else if(line==="\\else"){const f=stack.at(-1);if(!f)throw Error("DIRECTIVE");active=f.parent&&!f.condition;}
 else if(line==="\\endif"){if(!stack.length)throw Error("DIRECTIVE");active=stack.pop().parent;}
 else throw Error("UNREVIEWED_PSQL_DIRECTIVE");
 }if(stack.length)throw Error("DIRECTIVE");return out.join("\n");
}
export function statements(sql){let start=0,i=0,quote=null,dollar=null,comment=0,line=false,out=[];
 for(;i<sql.length;i++){const c=sql[i],n=sql[i+1];if(line){if(c==='\n')line=false;continue;}if(comment){if(c==='/'&&n==='*'){comment++;i++;}else if(c==='*'&&n==='/'){comment--;i++;}continue;}
 if(dollar){if(sql.startsWith(dollar,i)){i+=dollar.length-1;dollar=null;}continue;}
 if(quote){if(c===quote){if(n===quote)i++;else quote=null;}continue;}
 if(c==='-'&&n==='-'){line=true;i++;continue;}if(c==='/'&&n==='*'){comment=1;i++;continue;}if(c==="'"||c==='"'){quote=c;continue;}
 const m=c==='$'?sql.slice(i).match(/^\$(?:[a-zA-Z_][a-zA-Z_0-9]*)?\$/):null;if(m){dollar=m[0];i+=dollar.length-1;continue;}
 if(c===';'){out.push(sql.slice(start,i));start=i+1;}}
 if(quote||dollar||comment)throw Error('SQL_LEXER');if(sql.slice(start).trim())out.push(sql.slice(start));return out.filter(s=>s.replace(/--[^\n]*/g,'').trim());}
const suites={L01:['teacher_public_discovery_rls.test.sql','teacher_security_fix_rls.test.sql','student_teacher_trial_flow_rls.test.sql','trial_security_hardening.test.sql'],L02:['commerce_products_orders_payments.test.sql','commerce_security_hardening.test.sql','commerce_service_role_authority.test.sql'],L03:['entitlement_lesson_credits.test.sql','consume_lesson_credit_teacher_role.test.sql','entitlement_revoke_booking_consistency_contract.test.sql','entitlement_revoke_idempotency.test.sql'],L04:['scheduling_booking_core.test.sql','makeup_booking_lifecycle.test.sql','schedule_locking_contract.test.sql','fixed_renewal_lifecycle_contract.test.sql']};
export async function legacy(file,id,dir){
 const plan=compileCase(id),start=new Date().toISOString(),writer=await open(file),before=await observe(file,plan,writer.identity.pid,false),results=[];let stop=null,after;
 try{
 const tables=Object.keys(before.allTables);if(tables.some(t=>! /^(public|auth)\.[a-z_]+$/.test(t)))throw Error('TABLE_NAME');
 const counts={text:"select jsonb_object_agg(t,n) as value from ("+tables.map(t=>`select '${t}' t,count(*)::int n from ${t}`).join(' union all ')+') q',values:[]};
 for(const name of suites[id]){
  const expectedBudget=process.argv.includes('--measure')?null:JSON.parse(readFileSync('tools/epic7-local-engineering/legacy-budget-'+id+'.json','utf8')).find(x=>x.name===name);
  const sql=source(name),steps=statements(directives(sql)),peak=Object.fromEntries(tables.map(t=>[t,0])),trace=[];let assertions=0;
  for(let index=0;index<steps.length;index++){
   const output=await writer.raw(steps[index]);if(/^not ok|Looks like you failed|No tests run/m.test(output))throw Error('TAP_FAILURE');assertions+=(output.match(/^ok \d+/gm)||[]).length;
   const role=(await writer.query({text:'select current_user as role',values:[]}))[0].role;
   if(!['postgres','anon','authenticated','service_role'].includes(role))throw Error('ROLE');
   await writer.raw('reset role');const current=(await writer.query(counts))[0].value;
   if(role!=='postgres')await writer.raw('set local role '+role);
   const deltas=Object.fromEntries(tables.map(t=>[t,current[t]-Number(before.allTables[t].count)]));
   for(const t of tables)peak[t]=Math.max(peak[t],deltas[t]);const sparse=Object.fromEntries(Object.entries(deltas).filter(([,n])=>n!==0));if(!trace.length||JSON.stringify(trace.at(-1).delta)!==JSON.stringify(sparse))trace.push({index,delta:sparse});if(expectedBudget){assert.equal(hash(sql),expectedBudget.sourceHash,'LEGACY_SOURCE_DRIFT');assert.deepEqual(sparse,expectedBudget.trace.filter(c=>c.index<=index).at(-1).delta,'LEGACY_STEP_BUDGET_DRIFT');}
  }
  assert.ok(assertions>0,'NO_ASSERTIONS');
  results.push({name,sourceHash:hash(sql),assertions,peak:Object.fromEntries(Object.entries(peak).filter(([,n])=>n!==0)),trace});
 }
 }catch(e){stop={reason:e.code??e.message};}finally{try{await writer.close();}catch{stop??={reason:'CLOSE_FAILED'};}}
 try{after=await observe(file,plan,writer.identity.pid,true);assert.equal(reconcile(plan,before,after,writer.identity.pid).status,'PASS');}catch{stop??={reason:'RESIDUE_FAILED'};}
 const budget=results.map(({name,sourceHash,peak,trace})=>({name,sourceHash,peak,trace}));
 const budgetPath='tools/epic7-local-engineering/legacy-budget-'+id+'.json';
 if(!stop){if(process.argv.includes('--measure'))writeFileSync(dir+'/'+id+'-measured-budget.json',JSON.stringify(budget,null,2),{flag:'wx'});else assert.deepEqual(budget,JSON.parse(readFileSync(budgetPath,'utf8')),'LEGACY_BUDGET_DRIFT');}
 record(dir,id,{caseId:id,candidate,runId:plan.runId,start,end:new Date().toISOString(),identity:writer.identity,fixtureManifestHash:hash(budget),results,before,after,stop,result:stop?'FAIL':process.argv.includes('--measure')?'MEASURED_NOT_ACCEPTED':'PASS',rollback:'INDEPENDENTLY_CHECKED',remote:'NOT RUN'});
 console.log(JSON.stringify({caseId:id,stop,result:stop?'FAIL':'COMPLETE',assertions:results.reduce((n,r)=>n+r.assertions,0)}));if(stop)throw Error('LEGACY_STOP');
}
if(process.argv[2]==='--legacy'){const dir='artifacts/remote-smoke/epic7-pg-legacy-'+randomUUID();mkdirSync(dir,{recursive:true});console.log(dir);for(const id of process.argv.slice(4).filter(x=>x!=='--measure'))await legacy(process.argv[3],id,dir);}
