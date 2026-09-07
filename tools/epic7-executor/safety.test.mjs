import test, { before } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { ROOT,TARGET,BUDGETS,proveLocalContent,exampleManifest,validateManifest,canonical,digest,checkAttestation } from './contracts.mjs';
import { runSimulation,syntheticAttestation,main,writeEvidence } from './simulate.mjs';
import { reconcile } from './reconcile.mjs';
let proof;
before(async()=>{ proof=await proveLocalContent(); });
const clone=v=>structuredClone(v);
const input=(mode='ROLLBACK',cases)=>{const manifest=exampleManifest(mode,cases);return {proof,manifest,observed:syntheticAttestation(proof,manifest.runId)};};
const failed=(r,code)=>{assert.equal(r.report.status,'FAIL');assert.ok(r.report.stopReasons.includes(code),JSON.stringify(r.report.stopReasons));assert.equal(r.report.executionAllowed,false);assert.deepEqual(r.report.production,{connections:0,sql:0,writes:0});};
test('preserved proof binds 34 migrations, nine historical tools and application; not caller SHA',()=>{
  assert.equal(Object.keys(proof.migrations).length,34);assert.equal(Object.keys(proof.historicalToolHashes).length,9);assert.equal(proof.caseIds.length,37);
  assert.throws(()=>validateManifest(exampleManifest(),clone(proof)),/UNPROVEN_VERSION/);
});
test('rollback state machine records begin, visible sentinel, write, rollback, close and independent observer',async()=>{
  const r=await runSimulation(input());assert.equal(r.report.status,'PASS');
  assert.deepEqual(r.report.steps,['before','begin','sentinel','case:H01','rollback','close','independent-observer']);
  assert.equal(r.report.transaction.sentinel.visibleInWriter,true);assert.equal(r.report.transaction.sentinel.visibleInObserver,false);
  assert.ok(r.report.caseResults[0].changedRows>0);assert.equal(r.report.rollback,'PASS');assert.equal(r.independent.status,'PASS');
  assert.equal(r.report.residue,'PASS');assert.equal(r.report.after.writerClosed,true);assert.ok(Object.values(r.independent.counts).every(c=>c.actual===0));
});
test('committed proposal reconciles exact retained identities/digests, never claims production approval',async()=>{
  const args=input('COMMITTED_PROPOSAL',[{id:'R01',branch:'shipped'}]);const r=await runSimulation(args);
  assert.equal(r.report.status,'PASS');assert.equal(r.report.retention,'SYNTHETIC_EXPECTED');
  assert.ok(Object.values(r.independent.counts).some(c=>c.actual>0));assert.equal(args.manifest.approval,'NOT_APPROVED');assert.equal(r.report.executionAllowed,false);
});
for(const [name,change,code] of [
  ['project name',o=>o.target.name='other','WRONG_TARGET'],['project ref',o=>o.target.ref='other','WRONG_TARGET'],['region',o=>o.target.region='other','WRONG_TARGET'],
  ['candidate',o=>o.candidate='0'.repeat(40),'WRONG_VERSION'],['latest',o=>o.latest='20260904001100','MIGRATION_DRIFT'],
  ['missing migration',o=>delete o.migrations[Object.keys(o.migrations)[0]],'MIGRATION_DRIFT'],
  ['migration hash',o=>o.migrations[Object.keys(o.migrations)[0]]='0'.repeat(64),'MIGRATION_DRIFT'],
  ['app hash',o=>o.applicationHash='0'.repeat(64),'APPLICATION_DRIFT'],['old tool hash',o=>o.historicalToolHashes[Object.keys(o.historicalToolHashes)[0]]='0'.repeat(64),'TOOL_DRIFT'],
  ['new tool hash',o=>o.executorHashes['simulate.mjs']='0'.repeat(64),'TOOL_DRIFT'],['authority',o=>o.authority='ALLOW','AUTHORITY_DRIFT'],
  ['live attestation',o=>o.source='PRODUCTION','LIVE_ATTESTATION_UNAVAILABLE'],['stale receipt',o=>o.observedUTC='2000-01-01T00:00:00Z','STALE_ATTESTATION'],
  ['wrong run',o=>o.runId='other','WRONG_RUN'],['credentials field',o=>o.password='SECRET','INVALID_SHAPE']
])test('preflight stops before writer: '+name,async()=>{const args=input();change(args.observed);const r=await runSimulation(args);failed(r,code);assert.equal(r.report.backend,undefined);assert.equal(r.report.before,null);});
for(const [name,change,code] of [
  ['extra secret field',m=>m.token='SECRET','INVALID_SHAPE'],['caller approval',m=>m.approval='APPROVED','NO_EXECUTION_AUTHORITY'],
  ['budget increase',m=>m.tables['auth.users'].ceiling++,'BUDGET_EXCEEDED'],['wrong retained count',m=>m.tables['auth.users'].expectedRetained=1,'RETENTION_COUNT'],
  ['duplicate identity',m=>m.actors[1].id=m.actors[0].id,'DUPLICATE_ACTOR'],['real email',m=>m.actors[0].alias='someone@example.com','INVALID_ACTOR'],
  ['cross-course row',m=>m.tables['public.learning_nodes'].rows[0].map=m.scopes[1].map,'CROSS_SCOPE_ROW'],
  ['unknown table',m=>m.tables['public.students']={ceiling:1,rows:[],expectedRetained:0},'INVALID_SHAPE'],
  ['duplicate key',m=>m.tables['auth.users'].rows.push(clone(m.tables['auth.users'].rows[0])),'DUPLICATE_ROW'],
  ['missing table',m=>delete m.tables['public.audit_logs'],'INVALID_SHAPE'],['unknown case',m=>m.cases[0].id='ZZ1','INVALID_CASES'],
  ['retention claimed accepted',m=>m.retention.decision='ACCEPTED','UNAPPROVED_RETENTION']
])test('manifest rejects '+name,async()=>{const args=input();change(args.manifest);const r=await runSimulation(args);failed(r,code);assert.equal(r.report.backend,undefined);assert.ok(!JSON.stringify(r).includes('SECRET'));});
for(const id of ['P04','P05','P06','R04'])test(id+' success stays blocked; denial evidence stays distinct',async()=>{
  const args=input(id==='R04'?'COMMITTED_PROPOSAL':'ROLLBACK',[{id,branch:'denial'}]);const r=await runSimulation(args);assert.equal(r.report.status,'PASS');assert.equal(r.report.caseResults[0].result,'course_use_denied');
  args.manifest.cases[0].branch='success';failed(await runSimulation(args),'POSITIVE_AUTHORITY_BLOCKED');
});
test('races cannot borrow uncommitted fixture',async()=>failed(await runSimulation(input('ROLLBACK',[{id:'R01',branch:'shipped'}])),'CROSS_SESSION_NEEDS_COMMIT'));
test('authority-denied plans cannot allocate activity rows',async()=>{const args=input();args.manifest.tables['public.learning_self_activity'].rows=[clone(args.manifest.tables['auth.users'].rows[0])];failed(await runSimulation(args),'POSITIVE_AUTHORITY_BLOCKED');});
for(const [phase,kind,code] of [
  ['begin','command','COMMAND_FAILURE'],['case','command','CASE_FAILURE'],['case','transaction','CASE_FAILURE'],['case','rows','UNEXPECTED_ROWS'],
  ['rollback','rollback','ROLLBACK_FAILURE'],['case','residue','UNEXPECTED_RESIDUE'],['case','sequence','SEQUENCE_CHANGE'],['case','unscoped','UNSCOPED_CHANGE'],
  ['case','catalog','CATALOG_CHANGE'],['before','observer','OBSERVER_NOT_INDEPENDENT'],['case','role','TRANSACTION_FAILURE'],
  ['sentinel','sentinel','SENTINEL_FAILURE'],['case','timeout','TIMEOUT'],['case','cancel','CANCEL_NOT_CONFIRMED'],
  ['case','late-write','TIMEOUT'],['close','command','CLOSE_FAILURE'],['after','command','COMMAND_FAILURE'],['case','secret','CASE_FAILURE']
])test('fail closed: '+phase+'/'+kind,async()=>{
  const args=input('ROLLBACK',[{id:'H01',branch:'shipped'},{id:'H02',branch:'shipped'}]);
  const r=await runSimulation({...args,fault:{phase,kind},timeoutMs:10});failed(r,code);
  assert.ok(!JSON.stringify(r).includes('FAKE_SECRET'));assert.ok(!r.report.backend.calls.includes('commit'));
  if(phase==='case' && ['command','transaction','rows','role','timeout','cancel','late-write','secret'].includes(kind))assert.equal(r.report.backend.calls.filter(p=>p==='case').length,1);
  if(kind==='rollback')assert.equal(r.report.rollback,'FAIL');
  if(kind==='late-write'){await new Promise(resolve=>setTimeout(resolve,100));assert.equal(r.report.backend.active,0);assert.equal(r.report.residue,'PASS');}
});
test('observer detects same counts with replaced identity or changed bytes, and missing evidence',async()=>{
  const args=input('COMMITTED_PROPOSAL',[{id:'R01',branch:'shipped'}]);const r=await runSimulation(args);
  const after=clone(r.report.after);after.tables['public.audit_logs'][0].fingerprint='0'.repeat(64);
  assert.equal(reconcile({proof,manifest:args.manifest,before:r.report.before,after,writerId:r.report.backend? r.report.transaction.writerId:null,committed:true}).status,'FAIL');
  delete after.tables['auth.users'];assert.throws(()=>reconcile({proof,manifest:args.manifest,before:r.report.before,after,writerId:r.report.transaction.writerId,committed:true}),/INVALID_SHAPE/);
});
test('forged snapshot cannot call main writer result an independent observer',async()=>{
  const args=input();const r=await runSimulation(args);const after=clone(r.report.after);after.connectionId=r.report.transaction.writerId;
  assert.throws(()=>reconcile({proof,manifest:args.manifest,before:r.report.before,after,writerId:r.report.transaction.writerId,committed:false}),/OBSERVER_NOT_INDEPENDENT/);
});
test('timeouts must be bounded; new config cannot request infinite execution',async()=>failed(await runSimulation({...input(),timeoutMs:Infinity}),'INVALID_TIMEOUT'));
test('CLI never enables production or caller-supplied candidate/URL/approval',async()=>{
  for(const args of [[],['--production'],['--yes'],['--simulate','--production'],['--candidate',proof.candidate],['postgres://fake.invalid']])await assert.rejects(main(args),/PRODUCTION_DISABLED/);
});
test('artifact writer only accepts immutable internal results; rejects arbitrary credential payload',()=>{
  assert.throws(()=>writeEvidence({report:{password:'SECRET'},independent:null}),/UNTRUSTED_EVIDENCE/);
});
test('failure and success evidence can be saved separately without replacement',async()=>{
  const args=input();const result=await runSimulation(args);const path=writeEvidence(result);const hashes=JSON.parse(readFileSync(path+'/hashes.json'));assert.equal(Object.keys(hashes).length,3);
  assert.equal(JSON.parse(readFileSync(path+'/observer.json')).status,'PASS');assert.throws(()=>writeEvidence(result),/EVIDENCE_EXISTS/);
  const bad=input();bad.manifest.token='SECRET';const failedResult=await runSimulation(bad);const failurePath=writeEvidence(failedResult);assert.equal(JSON.parse(readFileSync(failurePath+'/fixture.json')),null);assert.ok(!readFileSync(failurePath+'/result.json','utf8').includes('SECRET'));
});
test('proposal ceilings and target are versioned; key order does not change manifest hash',()=>{
  const m=exampleManifest();assert.equal(validateManifest(m,proof),digest(m));assert.equal(canonical({...TARGET}),canonical({region:TARGET.region,ref:TARGET.ref,name:TARGET.name}));assert.equal(Object.keys(BUDGETS).length,28);assert.ok(ROOT);
});
test('attestation from future clock is rejected',()=>{const args=input();assert.throws(()=>checkAttestation(proof,args.observed,args.manifest.runId,0),/STALE_ATTESTATION/);});

test('sentinel leak into durable state fails before any case and cannot be cleaned to pass',async()=>{
  const r=await runSimulation({...input(),fault:{phase:'sentinel',kind:'sentinel-leak'}});
  failed(r,'SENTINEL_FAILURE');assert.ok(r.report.stopReasons.includes('UNEXPECTED_RESIDUE'));assert.equal(r.report.backend.calls.includes('case'),false);
});
test('existing run identity stops before begin',async()=>{
  const r=await runSimulation({...input(),fault:{phase:'before',kind:'collision'}});failed(r,'BASELINE_COLLISION');assert.equal(r.report.backend.calls.includes('begin'),false);
});
test('lost COMMIT acknowledgement is unknown and independent retained rows keep it FAIL',async()=>{
  const r=await runSimulation({...input('COMMITTED_PROPOSAL',[{id:'R01',branch:'shipped'}]),fault:{phase:'commit',kind:'commit-ack-lost'}});
  failed(r,'COMMIT_OUTCOME_UNKNOWN');assert.equal(r.report.retention,'UNKNOWN');assert.ok(r.report.stopReasons.includes('UNEXPECTED_RESIDUE'));
});
test('savepoint failure stops denial sequence instead of continuing with an aborted transaction',async()=>{
  const r=await runSimulation({...input('ROLLBACK',[{id:'P04',branch:'denial'},{id:'P05',branch:'denial'}]),fault:{phase:'case',kind:'savepoint'}});
  failed(r,'SAVEPOINT_FAILURE');assert.equal(r.report.backend.calls.filter(p=>p==='case').length,1);
});

test('observer rejects ambiguous commit state and identity substitution at equal row count',async()=>{
  const args=input('COMMITTED_PROPOSAL',[{id:'R01',branch:'shipped'}]);const r=await runSimulation(args);
  const shared={proof,manifest:args.manifest,before:r.report.before,after:r.report.after,writerId:r.report.transaction.writerId};
  assert.throws(()=>reconcile({...shared,committed:'false'}),/INVALID_COMMIT_STATE/);
  const after=clone(r.report.after);after.tables['public.audit_logs'][0].key=clone(args.manifest.tables['auth.users'].rows[0].key);
  assert.equal(reconcile({...shared,after,committed:true}).status,'FAIL');
});
for(const phase of ['before','begin','sentinel','rollback','commit','after'])test('deadline at '+phase+' never starts a later test after STOP',async()=>{
  const args=input(phase==='commit'?'COMMITTED_PROPOSAL':'ROLLBACK');
  const r=await runSimulation({...args,timeoutMs:10,fault:{phase,kind:'timeout'}});failed(r,'TIMEOUT');
  if(['before','begin','sentinel'].includes(phase))assert.equal(r.report.backend.calls.includes('case'),false);
});
