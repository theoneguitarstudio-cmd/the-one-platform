import assert from 'node:assert/strict';
import {mkdirSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {open,record} from './pg-local.mjs';
import {compileCase} from './compile.mjs';
import {observerQueries,reconcile} from './observe.mjs';
import {compileObserver,decodeObserver,discoverySQL} from './observer-program.mjs';
import {candidate,hash} from './schema.mjs';
export async function observe(file,plan,writerId,writerClosed){
 const reader=await open(file);
 try{
  await reader.raw('begin isolation level repeatable read read only');
  await reader.query({text:"select set_config('epic7_f.run_id',$1,true)",values:[plan.runId]});
  const inventory=await reader.query({text:discoverySQL,values:[]}),program=compileObserver(plan,inventory),replies={};
  for(const q of program.queries)replies[q.id]=await reader.query(q);
  return decodeObserver(plan,program,replies,{writerId,writerClosed,at:new Date().toISOString()}).snapshot;
 }finally{await reader.close();}
}
export async function asActor(writer,plan,actor){
 await writer.raw('reset role');
 if(['observer','fixture-owner'].includes(actor))return;
 const role=plan.actors[actor]?'authenticated':actor;
 if(!['anon','authenticated','service_role'].includes(role))throw Error('ACTOR');
 await writer.query({text:"select set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.role',$2,true),set_config('request.jwt.claims',$3,true)",values:[plan.actors[actor]??'',role,{sub:plan.actors[actor]??'',role}]});
 await writer.raw('set local role '+role);
}
export async function executeSteps(writer,plan){
 const events=[];
 for(let i=0;i<plan.steps.length;i++){
  const step=plan.steps[i];await asActor(writer,plan,step.actor);await writer.raw('savepoint epic7_step');
  let rows,error;
  try{rows=await writer.query(step.query);}catch(e){error=e;}
  const expected=step.query.expect;
  try{
   if(expected.kind==='error'){assert.ok(error,'EXPECTED_ERROR_MISSING');assert.equal(error.code,expected.code);if(expected.message!==null)assert.equal(error.message,expected.message);await writer.raw('rollback to savepoint epic7_step');}
   else{if(error)throw error;assert.equal(rows.length,expected.kind==='rows'?expected.count:1);if(expected.kind==='scalar')assert.deepEqual(rows[0].value,expected.value);
    if(expected.kind==='dto'){const walk=o=>{if(o&&typeof o==='object')for(const [k,v]of Object.entries(o)){assert.ok(!expected.forbidden.includes(k),'DTO_LEAK');walk(v);}};walk(rows[0].value);}}
   await writer.raw('release savepoint epic7_step');
   await writer.raw('reset role');
   for(const checkpoint of plan.checkpoints.filter(c=>c.afterStep===i+1&&c.label!=='race-final-expected')){
    const actual={};for(const q of observerQueries(plan))actual[q.table]=(await writer.query(q)).length;
    assert.deepEqual(actual,checkpoint.counts,'BUDGET_MISMATCH');
   }
  }catch(e){e.step=step.label;throw e;}
  events.push({step:step.label,result:'PASS'});
 }
 return events;
}
export async function serial(file,caseId,dir){
 const plan=compileCase(caseId),start=new Date().toISOString();
 record(dir,caseId+'-plan',plan);
 if(plan.status==='BLOCKED_AUTHORITY'){record(dir,caseId,{caseId,candidate,runId:plan.runId,start,end:new Date().toISOString(),result:'BLOCKED_AUTHORITY',fixtureManifestHash:plan.planHash,retained:0,remote:'NOT RUN'});return 'BLOCKED';}
 const writer=await open(file);let before,after,events=[],failure=null,rollback='NOT_RUN',residue=null;
 try{
  before=await observe(file,plan,writer.identity.pid,false);
  await writer.raw('begin');
  events=await executeSteps(writer,plan);
  await writer.raw('rollback');rollback='CONFIRMED';
 }catch(e){failure={reason:e.code??e.message,step:e.step??null};try{await writer.raw('rollback');rollback='CONFIRMED_AFTER_FAILURE';}catch{rollback='FAILED';}}
 finally{try{await writer.close();}catch{failure??={reason:"CLOSE_FAILED"};}}
 try{after=await observe(file,plan,writer.identity.pid,true);residue=reconcile(plan,before,after,writer.identity.pid);if(residue.status!=='PASS')failure??={reason:'RESIDUE_FAILED'};}catch(e){failure??={reason:e.message};}
 record(dir,caseId,{caseId,candidate,runId:plan.runId,fixtureManifestHash:plan.planHash,start,end:new Date().toISOString(),identity:writer.identity,events,rollback,before,after,residue,result:failure?'FAIL':'PASS',stop:failure,remote:'NOT RUN'});
 console.log(JSON.stringify({caseId,result:failure?'FAIL':'PASS',stop:failure}));
 if(failure)throw Error('CASE_STOP');return 'PASS';
}
if(process.argv[2]==='--serial'){
 const file=process.argv[3],dir='artifacts/remote-smoke/epic7-pg-cases-'+randomUUID();mkdirSync(dir,{recursive:true});console.log(dir);
 const cases=process.argv.slice(4);for(const id of cases)await serial(file,id,dir);
 record(dir,'summary',{cases,completed:new Date().toISOString(),hash:hash(cases)});
}
