// Closed in-memory simulator. No adapter injection, no URL/SQL/process/network API.
import { randomUUID } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ROOT,TARGET,CANDIDATE,BUDGETS,Stop,insist,exact,canonical,digest,sha,freeze,requireProof,proveLocalContent,validateManifest,checkAttestation,exampleManifest,assertCurrentContent } from './contracts.mjs';
import { reconcile,validateSnapshot } from './reconcile.mjs';
const clone = v => structuredClone(v);
const evidenceResults = new WeakMap();
const blank = () => Object.fromEntries(Object.keys(BUDGETS).map(t=>[t,[]]));
export function syntheticAttestation(proof, runId) {
  requireProof(proof);
  return {source:'SYNTHETIC_ONLY',runId,observedUTC:new Date().toISOString(),target:{...TARGET},candidate:CANDIDATE,
    latest:'20260906000500',migrations:clone(proof.migrations),applicationHash:proof.applicationHash,
    historicalToolHashes:clone(proof.historicalToolHashes),executorHashes:clone(proof.executorHashes),authority:'SHIPPED_FALSE'};
}
const PHASES=['before','begin','sentinel','case','rollback','commit','close','after'];
const FAULTS=['command','transaction','timeout','rows','rollback','residue','sequence','unscoped','catalog','observer','cancel','role','sentinel','late-write','secret','sentinel-leak','collision','commit-ack-lost','savepoint'];
function memoryBackend(manifest,fault) {
  let durable=blank(), transaction=null, closed=false, cancelled=false, sequence=0, outside=0, catalog=0, active=0;
  const writerId=randomUUID(), calls=[];
  const probe=manifest.tables['public.system_courses'].rows[0];
  if(fault.kind==='collision')durable['public.system_courses'].push({key:clone(probe.key),fingerprint:probe.fingerprint});
  async function step(phase,signal,fn) {
    calls.push(phase);
    if(fault.phase===phase) {
      if(['timeout','late-write','cancel'].includes(fault.kind)) {
        await new Promise((resolve,reject)=>{
          const timer=setTimeout(resolve,80);
          signal.addEventListener('abort',()=>{clearTimeout(timer);reject(new Stop('TIMEOUT'));},{once:true});
        });
      }
      if(['command','transaction','rollback','secret'].includes(fault.kind)) throw new Error(fault.kind === 'secret'?'password=FAKE_SECRET_DO_NOT_LOG':fault.kind);
    }
    insist(!signal.aborted && (!cancelled || phase === 'after'),'CANCELLED');
    return fn();
  }
  const snapshot=()=>({runId:manifest.runId,observerId:randomUUID(),connectionId:fault.kind==='observer'?writerId:randomUUID(),capturedUTC:new Date().toISOString(),writerClosed:closed,
    tables:clone(durable),unscopedDigest:digest(outside),catalogDigest:digest(catalog),sequenceDigest:digest(sequence),externalEffects:0});
  return {
    writerId,calls,
    async observe(phase,signal) { return step(phase,signal,()=>{
      if(phase==='after') {
        if(fault.kind==='residue') durable['public.audit_logs'].push({key:[randomUUID()],fingerprint:digest('unexpected')});
        if(fault.kind==='sequence') sequence++;
        if(fault.kind==='unscoped') outside++;
        if(fault.kind==='catalog') catalog++;
      }
      return snapshot();
    }); },
    async begin(signal) {return step('begin',signal,()=>{insist(!closed && transaction===null,'TRANSACTION_STATE');transaction=clone(durable);active++;return {transactionId:randomUUID(),writerId,active:true,role:'authenticated'};});},
    async sentinel(signal) {return step('sentinel',signal,()=>{
      insist(transaction!==null,'TRANSACTION_STATE');
      insist(probe,'MISSING_SENTINEL_FIXTURE');
      const row={key:clone(probe.key),fingerprint:probe.fingerprint};
      if(fault.kind!=='sentinel')transaction['public.system_courses'].push(row);
      if(fault.kind==='sentinel-leak')durable['public.system_courses'].push(clone(row));
      const matches=r=>canonical(r)===canonical(row);
      return {writerId,transactionActive:true,marker:manifest.runId,key:row.key,caseId:probe.caseId,rowsWritten:1,
        visibleInWriter:transaction['public.system_courses'].some(matches),visibleInObserver:durable['public.system_courses'].some(matches)};
    });},
    async runCase(c,signal) {return step('case',signal,()=>{
      insist(transaction!==null && !closed,'TRANSACTION_STATE');
      let changed=0;
      for(const [t,p]of Object.entries(manifest.tables)) for(const {caseId,key,fingerprint}of p.rows) if(caseId===c.id && !(t==='public.system_courses' && canonical(key)===canonical(probe.key))){transaction[t].push({key:clone(key),fingerprint});changed++;}
      // Model the expected permission error inside a savepoint; no activity mutation/policy stub.
      let savepoint='NOT_APPLICABLE';
      if(c.branch==='denial') {
        const saved=clone(transaction);
        try { throw new Stop('EXPECTED_DENIAL'); }
        catch(e) { insist(e.code==='EXPECTED_DENIAL','CASE_FAILURE'); transaction=saved; savepoint='ROLLED_BACK'; }
        if(fault.kind==='savepoint')throw new Stop('SAVEPOINT_FAILURE');
      }
      return {exit:0,transactionActive:true,savepoint,writerId,role:fault.kind==='role'?'postgres':'authenticated',changedRows:fault.kind==='rows'?changed+1:changed,sqlstate:c.branch==='denial'?'42501':'00000',domain:c.branch==='denial'?'course_use_denied':'synthetic_ok'};
    });},
    async finish(commit,signal) {return step(commit?'commit':'rollback',signal,()=>{insist(transaction!==null,'TRANSACTION_STATE');if(commit)durable=clone(transaction);transaction=null;active--;if(commit && fault.kind==='commit-ack-lost')throw new Stop('COMMIT_OUTCOME_UNKNOWN');return {writerId,transactionEnded:true,committed:commit};});},
    // Cancellation invalidates pending work before cleanup. Recovery is not a retry.
    cancel() {cancelled=true;return fault.kind!=='cancel';},
    async emergencyRollback(signal) {calls.push('failure-rollback');insist(!signal.aborted,'TIMEOUT');insist(fault.kind!=='rollback','ROLLBACK_FAILURE');transaction=null;active=0;return true;},
    async close(signal) { // Closing is permitted after cancellation and cannot write durable state.
      calls.push('close');insist(!signal.aborted,'TIMEOUT');if(fault.phase==='close')throw new Stop('CLOSE_FAILURE');closed=true;transaction=null;active=0;return {writerClosed:true,activeSessions:active};
    },
    stats:()=>({closed,active,calls:[...calls]})
  };
}
async function bounded(name, timeoutMs, fn) {
  const controller=new AbortController();let timer;
  try {
    return await Promise.race([Promise.resolve().then(()=>fn(controller.signal)),new Promise((_,reject)=>{
      timer=setTimeout(()=>{controller.abort();reject(new Stop('TIMEOUT'));},timeoutMs);
    })]);
  } catch(e) {if(e instanceof Stop)throw e;throw new Stop(name==='rollback'?'ROLLBACK_FAILURE':name==='case'?'CASE_FAILURE':'COMMAND_FAILURE');}
  finally {clearTimeout(timer);}
}
export async function runSimulation({proof,manifest,observed,fault={},timeoutMs=250}) {
  const startedUTC=new Date().toISOString();
  const report={schema:1,runId:randomUUID(),mode:'SYNTHETIC_ONLY',status:'FAIL',startedUTC,finishedUTC:null,target:{...TARGET},candidate:CANDIDATE,
    executionAllowed:false,production:{connections:0,sql:0,writes:0},caseIds:[],manifestHash:null,localContent:null,
    before:null,after:null,steps:[],caseResults:[],rollback:'NOT_STARTED',retention:'NOT_STARTED',residue:'NOT_CHECKED',stopReasons:[]};
  let backend,plan,before,safeManifest=null,committed=false,needsRollback=false,independent=null,finishingCommit=false;
  const fail=code=>{if(!report.stopReasons.includes(code))report.stopReasons.push(code);};
  try {
    insist(Number.isInteger(timeoutMs) && timeoutMs>=5 && timeoutMs<=1000,'INVALID_TIMEOUT');
    insist(Object.keys(fault).every(k=>['phase','kind'].includes(k)) && (!fault.phase||PHASES.includes(fault.phase)) && (!fault.kind||FAULTS.includes(fault.kind)), 'INVALID_FAULT');
    requireProof(proof);assertCurrentContent(proof);
    plan=freeze(clone(manifest));report.manifestHash=validateManifest(plan,proof);safeManifest=plan;report.runId=plan.runId;report.caseIds=plan.cases.map(c=>c.id);
    report.localContent={applicationHash:proof.applicationHash,reviewManifestHash:proof.reviewManifestHash,verifierHash:proof.verifierHash,historicalToolHashes:proof.historicalToolHashes,executorHashes:proof.executorHashes};
    checkAttestation(proof,observed,plan.runId);
    backend=memoryBackend(plan,fault);
    before=await bounded('before',timeoutMs,s=>backend.observe('before',s));validateSnapshot(before,plan.runId);report.before=before;
    insist(before.connectionId!==backend.writerId,'OBSERVER_NOT_INDEPENDENT');
    insist(Object.values(before.tables).every(rows=>rows.length===0),'BASELINE_COLLISION');report.before=before;report.steps.push('before');
    needsRollback=true; // Includes ambiguous begin failures.
    const begin=await bounded('begin',timeoutMs,s=>backend.begin(s));
    insist(begin.active && begin.writerId===backend.writerId && begin.role==='authenticated','TRANSACTION_STATE');
    report.steps.push('begin');
    const sentinel=await bounded('sentinel',timeoutMs,s=>backend.sentinel(s));
    insist(sentinel.writerId===backend.writerId && sentinel.marker===plan.runId && sentinel.transactionActive && sentinel.visibleInWriter && !sentinel.visibleInObserver,'SENTINEL_FAILURE');
    report.steps.push('sentinel');report.transaction={...begin,sentinel};
    for(const c of plan.cases) {
      const result=await bounded('case',timeoutMs,s=>backend.runCase(c,s));
      const expectedRows=Object.values(plan.tables).reduce((n,t)=>n+t.rows.filter(r=>r.caseId===c.id).length,0)-(sentinel.caseId===c.id?1:0);
      insist(result.exit===0 && result.transactionActive && result.writerId===backend.writerId && result.role==='authenticated','TRANSACTION_FAILURE');
      insist(result.changedRows===expectedRows,'UNEXPECTED_ROWS');
      insist(result.sqlstate===(c.branch==='denial'?'42501':'00000') && (c.branch!=='denial' || result.savepoint==='ROLLED_BACK') && result.domain===(c.branch==='denial'?'course_use_denied':'synthetic_ok'),'CASE_FAILURE');
      report.caseResults.push({id:c.id,branch:c.branch,mode:'SYNTHETIC_ONLY',changedRows:result.changedRows,sqlstate:result.sqlstate,savepoint:result.savepoint,result:result.domain});report.steps.push('case:'+c.id);
    }
    const keep=plan.mode==='COMMITTED_PROPOSAL';finishingCommit=keep;
    const end=await bounded(keep?'commit':'rollback',timeoutMs,s=>backend.finish(keep,s));
    insist(end.writerId===backend.writerId && end.transactionEnded && end.committed===keep,'TRANSACTION_FAILURE');
    committed=keep;needsRollback=false;report.steps.push(keep?'commit':'rollback');
    report.rollback=keep?'NOT_APPLICABLE':'PASS';report.retention=keep?'SYNTHETIC_EXPECTED':'NONE';
  } catch(e) {
    fail(e instanceof Stop?e.code:'INVALID_INPUT');
    if(finishingCommit)report.retention='UNKNOWN';
    if(backend && needsRollback) {
      if(!backend.cancel())fail('CANCEL_NOT_CONFIRMED');
      try {await bounded('rollback',timeoutMs,s=>backend.emergencyRollback(s));report.rollback='PASS';report.steps.push('failure-rollback');}
      catch {report.rollback='FAIL';fail('ROLLBACK_FAILURE');}
    }
  } finally {
    if(backend) {
      try {const closed=await bounded('close',timeoutMs,s=>backend.close(s));insist(closed.writerClosed && closed.activeSessions===0,'CLOSE_FAILURE');report.steps.push('close');}
      catch {fail('CLOSE_FAILURE');}
      if(before) {
        try {
          // Fresh connection to durable store after writer closed, not writer's snapshot/result.
          const after=await bounded('after',timeoutMs,s=>backend.observe('after',s));
          validateSnapshot(after,plan.runId);report.after=after;
          independent=reconcile({proof,manifest:plan,before,after,writerId:backend.writerId,committed});
          report.residue=independent.status;report.steps.push('independent-observer');
          for(const code of independent.reasons)fail(code);
        }catch(e){report.residue='UNKNOWN';fail(e instanceof Stop?e.code:'OBSERVER_FAILURE');}
      }
      report.backend=backend.stats();
    }
    report.finishedUTC=new Date().toISOString();
    report.status=report.stopReasons.length?'FAIL':'PASS';
  }
  const result=freeze({report,independent});
  evidenceResults.set(result,safeManifest);
  return result;
}
export function writeEvidence(result) {
  insist(evidenceResults.has(result),"UNTRUSTED_EVIDENCE");
  const manifest=evidenceResults.get(result);
  // Internal CLI only produces allowlisted synthetic data. No caller paths/raw logs/credentials.
  exact(result,['report','independent']);
  insist(result.report.mode==='SYNTHETIC_ONLY' && (!manifest || result.report.manifestHash===digest(manifest)),'INVALID_EVIDENCE');
  const output=resolve(ROOT,'artifacts/remote-smoke/epic7-executor-preparation',result.report.runId);
  insist(!existsSync(output),'EVIDENCE_EXISTS');mkdirSync(output,{recursive:true});
  for(const [name,value]of Object.entries({'result.json':result.report,'observer.json':result.independent,'fixture.json':manifest}))writeFileSync(resolve(output,name),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
  const hashes=Object.fromEntries(['result.json','observer.json','fixture.json'].map(n=>[n,sha(readFileSync(resolve(output,n)))]));
  writeFileSync(resolve(output,'hashes.json'),JSON.stringify(hashes,null,2)+'\n',{flag:'wx'});
  return output;
}
export async function main(args) {
  insist(canonical(args)===canonical(['--simulate']),'PRODUCTION_DISABLED');
  let proof;
  try { proof=await proveLocalContent(); } catch { /* Persist a safe UNPROVEN_VERSION failure, never raw source/errors. */ }
  const manifest=exampleManifest();
  const result=await runSimulation({proof,manifest,observed:proof?syntheticAttestation(proof,manifest.runId):null});
  const output=writeEvidence(result);
  return {status:result.report.status,mode:'SYNTHETIC_ONLY',executionAllowed:false,production:result.report.production,output};
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url))main(process.argv.slice(2)).then(r=>{console.log(JSON.stringify(r,null,2));if(r.status!=='PASS')process.exitCode=1;}).catch(()=>{console.error('STOP: preparation failed; production execution is unavailable');process.exitCode=1;});
