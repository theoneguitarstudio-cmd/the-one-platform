import test from 'node:test';
import assert from 'node:assert/strict';
import {compileCase} from './compile.mjs';
import {CASES} from '../epic7-owner-policy.mjs';
import {hash,tableKeys} from './schema.mjs';
import {compileObserver,decodeObserver,discoverySQL,catalogSQL} from './observer-program.mjs';
import {auditBudget,localReadiness} from './budget-review.mjs';
import {reconcileCommitted} from './observe.mjs';

const plans=CASES.map(compileCase),p=plans.find(p=>p.caseId==='R01');
const inventory=Object.keys(tableKeys).map(t=>({schema:t.split('.')[0],name:t.split('.')[1],kind:'r'}));
inventory.push({schema:'public',name:'unrelated_table',kind:'r'},{schema:'public',name:'test_sequence',kind:'S'});
const program=compileObserver(p,inventory);
const context={writerId:1,writerClosed:true,at:'2026-09-07T00:00:00.000Z'};
function replies(pid=2){
 return Object.fromEntries(program.queries.map(q=>[q.id,q.id==='identity'?[{pid,database:'epic7_race_20260906',marker:p.runId,readonly:'on',isolation:'repeatable read'}]:
  q.id==='inventory'?structuredClone(inventory):q.id.startsWith('scope:')?[]:q.id.startsWith('sequence:')?[{last_value:'1',is_called:false}]:[{count:'0',fingerprint:hash('empty')}]]));
}
test('read program covers every table, complement, sequence and metadata with no transport',()=>{
 assert.equal(program.queries.filter(q=>q.id.startsWith('all:')).length,29);
 assert.equal(program.queries.filter(q=>q.id.startsWith('scope:')).length,28);
 assert.equal(program.queries.filter(q=>q.id.startsWith('unscoped:')).length,28);
 assert.match(program.begin,/repeatable read read only/);
 assert.equal(program.productionAllowed,false);assert.equal(program.executed,false);
 assert.match(discoverySQL,/'f','m'/);
 for(const term of ['pg_attribute','pg_attrdef','pg_policy','pg_trigger','pg_proc','pg_auth_members','pg_extension'])assert.ok(catalogSQL.includes(term));
 for(const q of program.queries){assert.ok(!q.text.includes(p.runId));assert.ok(!/\b(?:delete|insert|update|setval|repair)\b/i.test(q.text));}
 const complement=program.queries.find(q=>q.id==='unscoped:public.audit_logs');
 assert.match(complement.text,/\) is not true/);assert.equal(complement.values.length,3);
});
test('complete decoding returns only non-secret digests, independent identity and immutable snapshot',()=>{
 const result=decodeObserver(p,program,replies(),context);
 assert.equal(result.snapshot.connectionId,2);assert.equal(result.productionEvidence,false);
 assert.equal(result.domainTestExecuted,false);assert.equal(Object.isFrozen(result.snapshot.tables),true);
 assert.ok(result.snapshot.unscopedHash);assert.ok(result.snapshot.sequenceHash);
 assert.equal(result.snapshotHash,hash(result.snapshot));
});
for(const [label,mutate] of [
 ['missing table',x=>{x.splice(0,1);}],
 ['duplicate table',x=>{x.push(x[0]);}],
 ['unreviewed schema',x=>{x.push({schema:'external',name:'data',kind:'r'});}],
 ['foreign table',x=>{x.push({schema:'public',name:'external_data',kind:'f'});}],
 ['materialized view',x=>{x.push({schema:'public',name:'mv',kind:'m'});}],
 ['identifier injection',x=>{x[0].name='users; select 1';}],
 ['extra field',x=>{x[0].credential='do not retain';}]
])test('discovery rejects '+label,()=>{const x=structuredClone(inventory);mutate(x);assert.throws(()=>compileObserver(p,x),/OBSERVER/);});
for(const [label,mutate] of [
 ['inventory drift',x=>{x.inventory.pop();}],
 ['sequence overflow',x=>{x['sequence:public.test_sequence'][0].last_value='9223372036854775808';}],
 ['missing result',x=>{delete x['all:auth.users'];}],
 ['extra result',x=>{x.credentials='secret';}],
 ['same writer',x=>{x.identity[0].pid=1;}],
 ['wrong target',x=>{x.identity[0].database='production';}],
 ['wrong run',x=>{x.identity[0].marker='wrong';}],
 ['writable reader',x=>{x.identity[0].readonly='off';}],
 ['weak isolation',x=>{x.identity[0].isolation='read committed';}],
 ['missing sequence',x=>{x['sequence:public.test_sequence']=[];}],
 ['hidden sequence',x=>{x['sequence:public.test_sequence'][0].last_value=null;}],
 ['unsafe integer count',x=>{x['all:auth.users'][0].count='9223372036854775808';}],
 ['numeric count',x=>{x['all:auth.users'][0].count=0;}],
 ['raw row body',x=>{x['scope:auth.users']=[{key:['id'],fingerprint:hash('x'),email:'must not emit'}];}],
 ['driver error',x=>{x.catalog=[{error:'secret raw error'}];}]
])test('decoder fails closed on '+label,()=>{const x=replies();mutate(x);assert.throws(()=>decodeObserver(p,program,x,context),/OBSERVER/);});
test('caller cannot forge program, plan or independence context',()=>{
 assert.throws(()=>decodeObserver(p,{...program},replies(),context),/BINDING/);
 assert.throws(()=>decodeObserver({...p},program,replies(),context),/UNTRUSTED_PLAN/);
 assert.throws(()=>decodeObserver(p,program,replies(),{...context,writerId:null}),/CONTEXT/);
 assert.throws(()=>decodeObserver(plans[0],program,replies(),context),/BINDING/);
});
test('sequence use and unrelated table changes alter independent digest; no cleanup is permitted',()=>{
 const a=decodeObserver(p,program,replies(2),context).snapshot;
 const b=replies(3);b['sequence:public.test_sequence'][0].is_called=true;
 assert.notEqual(decodeObserver(p,program,b,context).snapshot.sequenceHash,a.sequenceHash);
 const c=replies(4);c['all:public.unrelated_table'][0].fingerprint=hash('changed');
 assert.notEqual(decodeObserver(p,program,c,context).snapshot.unscopedHash,a.unscopedHash);
 assert.equal(reconcileCommitted(p,a,decodeObserver(p,program,b,context).snapshot,decodeObserver(p,program,c,context).snapshot,1).status,'FAIL');
});
test('37 budgets preserve trigger peaks, keys and explicitly unknown legacy effects',()=>{
 for(const plan of plans){
  const b=auditBudget(plan);assert.equal(Object.keys(b.tables).length,28);
  assert.equal(b.budgetVerifiedByDatabase,false);assert.equal(b.fixtureCreationAllowed,false);
  if(plan.sources.length){assert.equal(b.totals.finalRows,null);assert.equal(b.budgetComplete,false);}
  else for(const t of Object.values(b.tables)){assert.ok(t.expectedPeak<=t.ceiling);assert.ok(t.expectedPeak>=t.expectedFinal);}
 }
 const h=auditBudget(plans.find(p=>p.caseId==='H05'));
 assert.equal(h.tables['public.user_roles'].expectedPeak,12);
 assert.equal(h.tables['public.user_roles'].expectedFinal,8);
 assert.equal(h.totals.retainedAfterRollback,0);
 const r=auditBudget(p);assert.equal(r.totals.isolatedCommitProposal,r.totals.finalRows);
});
test('readiness cannot become PASS from compiled cases or caller approval',()=>{
 const r=localReadiness(plans);assert.equal(r.remoteExecutionReady,false);
 assert.equal(r.status,'BLOCKER');assert.equal(r.engineering.length,6);
 assert.deepEqual(r.legacyBudgetUnknown,['L01','L02','L03','L04']);
 assert.deepEqual(r.authorityGaps,['P04','P05','P06','R04']);
 assert.throws(()=>localReadiness([...plans.slice(1),plans[1]]),/CASE_IDS/);
 assert.throws(()=>localReadiness(plans.slice(1)),/CASE_COUNT/);
 assert.throws(()=>localReadiness(plans.map(p=>({...p,approved:true}))),/UNTRUSTED_PLAN/);
});
