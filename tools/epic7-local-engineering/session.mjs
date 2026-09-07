import {requireTestTransport} from './test-double.mjs';
// Driver-neutral protocol exercised only with explicit test doubles. No pg/net/process/env imports.
import {randomUUID} from 'node:crypto';
import {requirePlan} from './compile.mjs';
import {hash,immutable,fail} from './schema.mjs';
import {reconcile,validateSnapshot} from './observe.mjs';
const reports=new WeakSet();
const reasons=new Set(['CONNECT_FAILED','DEADLINE','CANCEL_FAILED','CLOSE_FAILED','WRONG_LOCAL_TARGET','WRONG_SESSION',
 'WRONG_TRANSACTION','COMMAND_FAILED','UNEXPECTED_ROWS','UNEXPECTED_VALUE','EXPECTED_ERROR_MISSING',
 'WRONG_SQLSTATE','WRONG_DOMAIN','BUDGET_MISMATCH','DTO_LEAK','SENTINEL_FAILED','ROLLBACK_FAILED','OBSERVER_FAILED',
 'RESIDUE_FAILED','CASE_NOT_RUNNABLE','INVALID_TIMEOUT','UNTRUSTED_PLAN']);
export function requireReport(r){if(!reports.has(r))fail('UNTRUSTED_REPORT');}
const canonical=x=>Array.isArray(x)?'['+x.map(canonical).join(',')+']':x&&typeof x==='object'?'{'+Object.keys(x).sort().map(k=>JSON.stringify(k)+':'+canonical(x[k])).join(',')+'}':JSON.stringify(x);
function assertResult(result,expected){
 if(!result||!Array.isArray(result.rows)||!Number.isInteger(result.rowCount))fail('UNEXPECTED_ROWS');
 if(expected.kind==='error')fail('EXPECTED_ERROR_MISSING');
 if(expected.kind==='rows'){if(result.rowCount!==expected.count)fail('UNEXPECTED_ROWS');return;}
 if(result.rowCount!==1||result.rows.length!==1||!Object.hasOwn(result.rows[0],'value'))fail('UNEXPECTED_ROWS');
 const v=result.rows[0].value;
 if(expected.kind==='scalar'&&canonical(v)!==canonical(expected.value))fail('UNEXPECTED_VALUE');
 if(expected.kind==='dto'){
  if(!v||typeof v!=='object'||Array.isArray(v))fail('UNEXPECTED_VALUE');
  const walk=x=>{if(x&&typeof x==='object')for(const [k,value] of Object.entries(x)){
    if(expected.forbidden.includes(k))fail('DTO_LEAK');walk(value);}};
  walk(v);
 }
}
export async function exerciseSession(plan,transport,{timeoutMs=100}={}){
 const runId=randomUUID(), started=new Date().toISOString(), events=[], stop=[];
 let boundBackend=null;
 let writer=null,before=null,after=null,active=false,closed=false,rollback='NOT_STARTED',observer=null;
 const bounded=async(fn,session=null)=>{
   const controller=new AbortController();let timer;let timedOut=false;
   const work=Promise.resolve().then(()=>fn(controller.signal));
   const timeout=new Promise((_,reject)=>{timer=setTimeout(()=>{timedOut=true;controller.abort();reject(new Error('DEADLINE'));},timeoutMs);});
   try{return await Promise.race([work,timeout]);}
   catch(e){
    if(timedOut&&session){
     // Cancellation acknowledgement itself is bounded. A caller-side timeout is never proof of DB cancellation.
     let cancelTimer;
     try{const ack=await Promise.race([Promise.resolve().then(()=>session.cancel()),new Promise((_,reject)=>{cancelTimer=setTimeout(()=>reject(new Error('CANCEL_FAILED')),timeoutMs);})]);
       if(ack!==true)stop.push('CANCEL_FAILED');
     }catch{stop.push('CANCEL_FAILED');}finally{clearTimeout(cancelTimer);}
    }
    throw e;
   }finally{clearTimeout(timer);}
 };
 const check=()=>{
   if(!writer||writer.identity.environment!=='ISOLATED_TEST_DOUBLE'||writer.identity.runId!==plan.runId)fail('WRONG_LOCAL_TARGET');
   if(!Number.isInteger(writer.identity.backendId)||writer.identity.backendId<1)fail('WRONG_SESSION');
   if(boundBackend===null)boundBackend=writer.identity.backendId;
   if(boundBackend!==writer.identity.backendId)fail('WRONG_SESSION');
 };
 const close=async()=>{if(writer&&!closed){try{await bounded(()=>writer.close());if(writer.closed!==true)fail('CLOSE_FAILED');closed=true;events.push('CLOSE');}catch{stop.push('CLOSE_FAILED');}}};
 try{
  requirePlan(plan);
  if(!Number.isInteger(timeoutMs)||timeoutMs<5||timeoutMs>1000)fail('INVALID_TIMEOUT');
  if(plan.status!=='COMPILED_NOT_EXECUTED'||plan.races)fail('CASE_NOT_RUNNABLE');
  requireTestTransport(transport);
  // A late successful connect must be disposed, not leaked or used to resume a timed-out run.
  let connectExpired=false;
  try{writer=await bounded(async signal=>{
    const s=await transport.open(plan.runId,signal);
    if(connectExpired||signal.aborted){try{await s.close();}catch{ /* never log driver errors */ }fail('DEADLINE');}
    return s;
  });}catch(e){connectExpired=true;throw new Error(e.message==='DEADLINE'?'DEADLINE':'CONNECT_FAILED');}
  check();
  before=await bounded(signal=>transport.observe(plan,signal,false));events.push('BEFORE');
  validateSnapshot(before,plan);
  if(!before||before.connectionId===writer.identity.backendId)fail('OBSERVER_FAILED');
  if(Object.values(before.tables??{}).some(rows=>rows.length))fail('SENTINEL_FAILED');
  active=true;await bounded(signal=>writer.begin(signal),writer);events.push('BEGIN');
  if(writer.transactionStatus!=='T')fail('WRONG_TRANSACTION');
  await bounded(signal=>writer.configure({statementTimeoutMs:timeoutMs,lockTimeoutMs:Math.max(1,Math.floor(timeoutMs/2)),idleTimeoutMs:timeoutMs},signal),writer);
  // Sentinel is a dedicated TEMP row; it creates no committed Course or permanent schema object.
  const sentinel=await bounded(signal=>writer.sentinel(plan.runId,signal),writer);
  if(sentinel?.before!==0||sentinel?.inside!==1||sentinel?.outside!==0)fail('SENTINEL_FAILED');
  events.push('SENTINEL');
  let stepNumber=0;
  const verifyBudget=async()=>{
   for(const checkpoint of plan.checkpoints.filter(c=>c.afterStep===stepNumber)){
    const actual=await bounded(signal=>writer.scopeCounts(plan,signal),writer);
    if(!actual||Object.keys(actual).length!==Object.keys(checkpoint.counts).length||Object.entries(checkpoint.counts).some(([table,count])=>actual[table]!==count))fail('BUDGET_MISMATCH');
   }
  };
  for(const step of plan.steps){
   stepNumber++;
   check();if(writer.transactionStatus!=='T')fail('WRONG_TRANSACTION');
   await bounded(signal=>writer.asActor(step.actor,plan.actors[step.actor]??null,signal),writer);
   check();if(writer.actor!==step.actor)fail('WRONG_SESSION');
   await bounded(signal=>writer.savepoint(signal),writer);
   let outcome;
   try{outcome=await bounded(signal=>writer.query(step.query,signal),writer);}
   catch(e){
    if(e.message==='DEADLINE')throw e;
    if(step.query.expect.kind!=='error')fail('COMMAND_FAILED');
    if(e.code!==step.query.expect.code)fail('WRONG_SQLSTATE');
    if(step.query.expect.message!==null&&e.message!==step.query.expect.message)fail('WRONG_DOMAIN');
    await bounded(signal=>writer.rollbackSavepoint(signal),writer);
    if(writer.transactionStatus!=='T')fail('WRONG_TRANSACTION');
    await verifyBudget();events.push(step.label+':EXPECTED_DENIAL');continue;
   }
   check();assertResult(outcome,step.query.expect);
   await bounded(signal=>writer.releaseSavepoint(signal),writer);
   if(writer.transactionStatus!=='T')fail('WRONG_TRANSACTION');
   await verifyBudget();events.push(step.label+':MATCH');
  }
  await bounded(signal=>writer.rollback(signal),writer);
  if(writer.transactionStatus!=='I')fail('ROLLBACK_FAILED');
  active=false;rollback='CONFIRMED';events.push('ROLLBACK');
 }catch(e){stop.push(reasons.has(e.message)?e.message:'COMMAND_FAILED');}
 finally{
  if(active&&writer){
   try{await bounded(signal=>writer.rollback(signal),writer);if(writer.transactionStatus!=='I')fail('ROLLBACK_FAILED');rollback='RECOVERY_CONFIRMED';active=false;}
   catch{rollback='FAILED';stop.push('ROLLBACK_FAILED');}
  }
  await close();
  if(writer&&before){
   try{
    after=await bounded(signal=>transport.observe(plan,signal,closed));
    observer=reconcile(plan,before,after,writer.identity.backendId);
    if(observer.status!=='PASS')stop.push('RESIDUE_FAILED');
    // Independent sentinel check after rollback/close, not writer's assertion of successful cleanup.
    if(await bounded(signal=>transport.sentinelResidue(plan.runId,signal))!==0)stop.push('SENTINEL_FAILED');
   }catch{stop.push('OBSERVER_FAILED');}
  }
 }
 const report=immutable({format:1,runId,fixtureRunId:trustedRunId(plan),caseId:trustedCaseId(plan),planHash:trustedHash(plan),
  started,finished:new Date().toISOString(),mode:'OFFLINE_CONTROL_TEST',status:stop.length?'FAIL':'PASS',
  steps:events,rollback,writerClosed:closed,observer,stopReasons:[...new Set(stop)],
  production:{connections:0,sql:0,writes:0},domainTestExecuted:false,remoteStatus:'REMOTE NOT RUN'});
 reports.add(report);return report;
}
function trustedRunId(p){try{requirePlan(p);return p.runId;}catch{return null;}}
function trustedCaseId(p){try{requirePlan(p);return p.caseId;}catch{return null;}}
function trustedHash(p){try{requirePlan(p);return p.planHash;}catch{return hash('UNTRUSTED_PLAN');}}
