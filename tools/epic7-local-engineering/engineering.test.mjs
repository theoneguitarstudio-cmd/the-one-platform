import {createTestDouble as fake} from './test-double.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {CASES} from '../epic7-owner-policy.mjs';
import {compileCase} from './compile.mjs';
import {tableKeys,hash} from './schema.mjs';
import {observerQueries,fullTableDigestQuery,reconcile,reconcileCommitted} from './observe.mjs';
import {exerciseSession} from './session.mjs';
import {writeEvidence} from './evidence.mjs';
const plans=new Map(CASES.map(id=>[id,compileCase(id)]));
const emptySnapshot=(p,connectionId=2)=>({runId:p.runId,connectionId,at:new Date().toISOString(),writerClosed:true,
 tables:Object.fromEntries(Object.keys(tableKeys).map(t=>[t,[]])),catalogHash:hash('catalog'),sequenceHash:hash('sequence'),
 allTables:{'public.system_courses':{count:'0',fingerprint:hash('empty')},'auth.users':{count:'0',fingerprint:hash('empty')}}});

for(const id of CASES)test('compile '+id+' without SQL execution',()=>{
 const p=plans.get(id);assert.equal(p.caseId,id);assert.equal(p.productionAllowed,false);assert.equal(p.fullCaseProven,false);
 assert.equal(Object.keys(p.rows).length,28);assert.equal(Object.keys(p.identity.migrations).length,34);
 for(const r of Object.values(p.rows)){assert.ok(r.count<=r.ceiling);assert.equal(r.count,r.keys.length);}
 for(const s of p.steps){
  assert.ok(!/\b(?:grant|truncate|disable trigger|setval|create or replace function)\b/i.test(s.query.text));
  assert.ok(!s.query.text.includes(p.runId),'values must not be interpolated in SQL');
  assert.equal((s.query.text.match(/\$\d+/g)??[]).length,s.query.values.length);
 }
 if(['P04','P05','P06','R04'].includes(id)){assert.equal(p.status,'BLOCKED_AUTHORITY');assert.equal(p.steps.length,0);}
});
test('original F shape and trigger accounting; exact retry adds no receipt/audit',()=>{
 const p=plans.get('H05');
 assert.deepEqual(Object.fromEntries(['auth.users','public.profiles','public.user_roles','public.curriculum_stages','public.learning_modules','public.learning_nodes','public.learning_mutation_receipts','public.audit_logs'].map(t=>[t,p.rows[t].count])),
  {'auth.users':8,'public.profiles':8,'public.user_roles':8,'public.curriculum_stages':2,'public.learning_modules':3,'public.learning_nodes':4,'public.learning_mutation_receipts':2,'public.audit_logs':4});
 assert.equal(p.checkpoints[0].counts['public.user_roles'],12);
 assert.equal(p.rows['public.profiles'].keys[0].length,1);
 assert.equal(p.rows['public.user_roles'].keys[0].length,2);
 assert.equal(p.rows['public.audit_logs'].keys[0].length,4);
});
test('race winner/retry budget and independent lock schedule',()=>{
 for(const id of ['R01','R02','R03']){
  const p=plans.get(id);assert.equal(p.rows['public.learning_mutation_receipts'].count,3);
  assert.equal(p.rows['public.audit_logs'].count,5);assert.equal(p.races.barrier,'FIRST_SESSION_VERSION_LOCK_HELD');
  assert.ok(Object.values(p.rows).every(r=>r.expectedRetained===r.count));
 }
 assert.equal(plans.get('R01').rows['public.learning_node_prerequisites'].count,1);
});
test('parameterized independent observer covers all 28 tables and generated audit UUID',()=>{
 const queries=observerQueries(plans.get('H05'));assert.equal(queries.length,28);
 const audit=queries.find(q=>q.table==='public.audit_logs');
 assert.match(audit.text,/after_snapshot->>'request_id'/);assert.match(audit.text,/generated_id/);
 assert.match(audit.text,/actor_user_id=any/);
 assert.ok(queries.every(q=>q.text.startsWith('with scope')&&q.values.length===3));
 assert.match(fullTableDigestQuery('public','orders').text,/sha256/);
 assert.throws(()=>fullTableDigestQuery('public','orders;delete'),/INVALID_IDENTIFIER/);
 assert.throws(()=>fullTableDigestQuery('private','orders'),/UNREVIEWED_SCHEMA/);
});
test('observer rejects same counts with different contents, missing tables, sequence and scope changes',()=>{
 const p=plans.get('H05'),before=emptySnapshot(p),after=emptySnapshot(p,3);
 assert.equal(reconcile(p,before,after,1).status,'PASS');
 for(const mutate of [
  a=>{a.connectionId=1;},a=>{delete a.tables['auth.users'];},
  a=>{a.tables['public.system_courses']=[{key:[p.runId],fingerprint:hash('extra')}];},
  a=>{a.allTables['public.system_courses'].fingerprint=hash('same count changed');},
  a=>{a.sequenceHash=hash('changed');},a=>{a.catalogHash=hash('changed');},a=>{a.writerClosed=false;}
 ]){
  const a=structuredClone(after);mutate(a);assert.equal(reconcile(p,before,a,1).status,'FAIL');
 }
});
test('success exercises protocol only, independently observes and preserves domain NOT RUN',async()=>{
 const p=plans.get('H05'),f=fake(p),r=await exerciseSession(p,f.transport);
 assert.equal(r.status,'PASS');assert.equal(r.domainTestExecuted,false);assert.equal(r.remoteStatus,'REMOTE NOT RUN');
 assert.equal(r.rollback,'CONFIRMED');assert.equal(r.observer.status,'PASS');
 assert.ok(f.calls.indexOf('observe')<f.calls.indexOf('begin'));
 assert.equal(f.calls.filter(x=>x==='observe').length,2);
 assert.ok(r.steps.some(s=>s.endsWith('EXPECTED_DENIAL')));
});
for(const name of ['budget','connect','target','sentinel','role','rows','rollback','close','observer','reusedReader','missingTable','residue','residueSentinel','sqlstate','domain','missingError','begin'])
 test('failure stops: '+name,async()=>{
  const p=plans.get('H05'),f=fake(p,{[name]:true}),r=await exerciseSession(p,f.transport);
  assert.equal(r.status,'FAIL');assert.ok(r.stopReasons.length);
  assert.ok(!JSON.stringify(r).includes('secret'));assert.ok(!JSON.stringify(r).includes('credential'));
  assert.ok(f.calls.filter(x=>x==='query').length<=p.steps.length);
  if(name==='missingTable')assert.ok(!f.calls.includes('begin'));
 });
test('unexpected command error stops all subsequent case commands',async()=>{
 const p=plans.get('H05'),f=fake(p,{queryAt:2}),r=await exerciseSession(p,f.transport);
 assert.equal(r.status,'FAIL');assert.equal(f.calls.filter(x=>x==='query').length,2);
 assert.ok(!JSON.stringify(r).includes('DO_NOT_LEAK'));
});
test('timeout cancels, blocks late query and does not turn rollback failure into PASS',async()=>{
 const p=plans.get('H05'),f=fake(p,{timeout:true,cancel:true,rollback:true});
 const r=await exerciseSession(p,f.transport,{timeoutMs:10});
 assert.equal(r.status,'FAIL');assert.ok(r.stopReasons.includes('DEADLINE'));
 assert.ok(r.stopReasons.includes('CANCEL_FAILED'));assert.ok(r.stopReasons.includes('ROLLBACK_FAILED'));
 await new Promise(r=>setTimeout(r,45));
 assert.equal(f.calls.filter(x=>x==='query').length,1);assert.ok(f.calls.includes('late-cancelled'));
});
test('late successful connection is closed and no transaction starts',async()=>{
 const p=plans.get('H05'),f=fake(p,{connectTimeout:true}),r=await exerciseSession(p,f.transport,{timeoutMs:10});
 assert.equal(r.status,'FAIL');await new Promise(r=>setTimeout(r,45));
 assert.equal(f.writer.closed,true);assert.ok(!f.calls.includes('begin'));
});
test('DTO leaks fail; authority/legacy/race plans cannot enter serial runner',async()=>{
 const p=plans.get('S04'),f=fake(p,{dto:true});assert.equal((await exerciseSession(p,f.transport)).status,'FAIL');
 for(const id of ['P04','L01','R01']){const p=plans.get(id),f=fake(p);assert.equal((await exerciseSession(p,f.transport)).status,'FAIL');assert.equal(f.calls.length,0);}
});
test('untrusted plan, transport and timeout cannot open a writer',async()=>{
 for(const [p,t,opt] of [[{},null,{}],[plans.get('H05'),{mode:'PRODUCTION'},{}],[plans.get('H05'),null,{timeoutMs:0}]]){
  const r=await exerciseSession(p,t,opt);assert.equal(r.status,'FAIL');
 }
});
test('evidence is bound, separate observer file, hashed and exclusive',async()=>{
 const p=plans.get('H05'),f=fake(p),r=await exerciseSession(p,f.transport);
 const directory=writeEvidence(p,r),base=new URL('../../'+directory+'/',import.meta.url);
 const manifest=JSON.parse(readFileSync(new URL('hashes.json',base),'utf8'));
 for(const [name,h] of Object.entries(manifest))assert.equal(hash(readFileSync(new URL(name,base))),h);
 assert.equal(JSON.parse(readFileSync(new URL('observer.json',base))).status,'PASS');
 assert.throws(()=>writeEvidence(p,r),/EEXIST/);
 assert.throws(()=>writeEvidence(plans.get('H01'),r),/EVIDENCE_BINDING/);
 assert.throws(()=>writeEvidence(p,{...r}),/UNTRUSTED_REPORT/);
 console.log('OFFLINE_EVIDENCE '+directory);
});

test('query payloads are snapshots: later negative test cannot corrupt successful reorder',()=>{
 const p=plans.get('H03');
 const good=p.steps.find(s=>s.label==='reorder').query.values[3];
 const bad=p.steps.find(s=>s.label==='duplicate-position').query.values[3];
 const zero=p.steps.find(s=>s.label==='nonpositive-position').query.values[3];
 assert.deepEqual(good.nodes.slice(0,2).map(n=>n.position),[2,1]);
 assert.deepEqual(bad.nodes.slice(0,2).map(n=>n.position),[2,2]);
 assert.equal(zero.nodes[0].position,0);
});
test('S01 source function metadata and S02 raw/private denials are actual query plans',()=>{
 const security=plans.get('S01'),raw=plans.get('S02');
 assert.equal(security.remaining.length,0);assert.equal(raw.remaining.length,0);
 assert.ok(security.steps.filter(s=>s.label.startsWith('function-')).length>30);
 assert.equal(raw.steps.filter(s=>s.label.startsWith('raw-deny-')).length,24*3*4);
 assert.ok(raw.steps.filter(s=>s.label.startsWith('private-deny-')).every(s=>s.query.text.startsWith('select private.learning_')));
});
test('all capability codes, independent completeness failures and V2 content have explicit plans',()=>{
 const caps=plans.get('C08').steps.find(s=>s.label==='all-capability-codes').query.values[3].capabilities;
 assert.deepEqual(caps.map(x=>x.code),['submission','verification','assessment']);
 assert.equal(plans.get('C08').rows['public.learning_capabilities'].count,4);
 assert.ok(plans.get('G02').steps.some(s=>s.label==='empty-stage-freeze'));
 assert.ok(plans.get('G02').steps.some(s=>s.label==='empty-module-freeze'));
 assert.equal(plans.get('V02').rows['public.learning_resource_versions'].count,8);
});
test('committed reconciliation checks exact inventory and independent confirmation, never allows cleanup',()=>{
 const p=plans.get('R01'),before=emptySnapshot(p);
 before.allTables=Object.fromEntries(Object.keys(tableKeys).map(t=>[t,{count:'0',fingerprint:hash('empty')}]));
 before.unscopedHash=hash('unscoped');
 const after=structuredClone(before);after.connectionId=3;
 for(const [t,r] of Object.entries(p.rows)){
  after.tables[t]=r.keys.map((key,i)=>({key,fingerprint:hash(t+JSON.stringify(key)),
   ...(t==='public.audit_logs'?{generated_id:'00000000-0000-4000-8000-'+String(i).padStart(12,'0')}:{})}));
  after.allTables[t]={count:String(r.count),fingerprint:r.count?hash(t+'written'):hash('empty')};
 }
 const confirmation=structuredClone(after);confirmation.connectionId=4;
 const pass=reconcileCommitted(p,before,after,confirmation,1);assert.equal(pass.status,'PASS');assert.equal(pass.executionAllowed,false);assert.equal(pass.cleanupAllowed,false);
 for(const mutate of [
  a=>{a.tables['public.audit_logs'].pop();},
  a=>{a.tables['public.system_courses'][0].fingerprint=hash('changed');},
  a=>{a.unscopedHash=hash('unexpected');},a=>{a.connectionId=1;},
  a=>{a.allTables['public.audit_logs'].count='999';},
  a=>{delete a.allTables['auth.users'];}
 ]){const c=structuredClone(confirmation);mutate(c);assert.equal(reconcileCommitted(p,before,after,c,1).status,'FAIL');}
});

test('a caller cannot replace the test double with a real connection factory',async()=>{
 let opened=false;
 const untrusted={mode:'ISOLATED_TEST_DOUBLE',open:()=>{opened=true;throw Error('must not run');}};
 const p=plans.get('H05'),r=await exerciseSession(p,untrusted);
 assert.equal(r.status,'FAIL');assert.equal(opened,false);
 const f=fake(p);assert.equal(Object.isFrozen(f.transport),true);
 assert.throws(()=>{f.transport.open=untrusted.open;},TypeError);
 assert.throws(()=>fake(p,{callback:()=>{}}),/INVALID_FAULT/);
});