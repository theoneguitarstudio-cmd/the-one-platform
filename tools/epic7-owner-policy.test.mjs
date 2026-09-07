import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {CASES,SERVICES,classifyCase,assessRecovery} from './epic7-owner-policy.mjs';
const example=()=>({scope:'WHOLE_SITE',controlledBy:'THE_ONE',encrypted:true,accessRestricted:true,
  custodianRecorded:true,retentionRecorded:true,restoreVerified:true,consistent:true,
  pointUTC:'2026-09-07T00:00:00.000Z',assessmentUTC:'2026-09-07T01:00:00.000Z',
  services:Object.fromEntries(SERVICES.map(k=>[k,'VERIFIED']))});
test('37 original case IDs and statuses preserved; documentation classification matches',()=>{
  const original=JSON.parse(fs.readFileSync(new URL('../scripts/epic7-readiness-cases.json',import.meta.url),'utf8'));
  assert.deepEqual(CASES,original.map(c=>c.id));
  assert.equal(original.every(c=>c.remoteStatus==='REMOTE NOT RUN' && c.approvedDeferral===false),true);
  const doc=fs.readFileSync(new URL('../docs/EPIC7_F_CASE_COVERAGE.md',import.meta.url),'utf8');
  for(const id of CASES) assert.ok(doc.includes('| '+id+' | '+classifyCase(id).route+' |'));
  const plan=fs.readFileSync(new URL('../docs/EPIC7_REMOTE_SMOKE_PLAN.md',import.meta.url),'utf8');
  assert.deepEqual([...plan.matchAll(/^\| ([SCHGVPRL]\d{2}) \|/gm)].map(m=>m[1]),CASES);
});
test('30 proposals, three isolated-only, four blocked, no automatic authorization or closure',()=>{
  const rows=CASES.map(classifyCase);
  for(const [route,n] of [['PRODUCTION_PROPOSAL',30],['ISOLATED_ONLY',3],['AUTHORITY_BLOCKED',4]])
    assert.equal(rows.filter(c=>c.route===route).length,n);
  assert.equal(classifyCase('R04').committed,true);
  assert.ok(rows.every(c=>!c.executionAllowed && !c.approvedDeferral && c.closure==='PROPOSED / PENDING APPROVAL'));
  assert.throws(()=>classifyCase('P07'),/UNKNOWN_CASE/);
});
test('exact one-hour boundary passes only a simulation, never BR or ongoing coverage',()=>{
  const r=assessRecovery(example());
  assert.equal(r.status,'SIMULATED_REQUIREMENTS_MET');
  assert.equal(r.executionAllowed,false);assert.equal(r.brPass,false);assert.equal(r.continuousRecoveryProven,false);
});
test('old, future, missing and impossible dates stop',()=>{
  for(const pointUTC of ['2026-09-06T23:59:59.999Z','2026-09-07T01:00:00.001Z',null,'2026-02-30T00:00:00.000Z'])
    assert.equal(assessRecovery({...example(),pointUTC}).status,'STOP');
});
test('employer storage, missing safeguards and logical-only restore stop',()=>{
  for(const [key,value] of [['controlledBy','EMPLOYER'],['scope','DB_ONLY'],
    ...['encrypted','accessRestricted','custodianRecorded','retentionRecorded','restoreVerified','consistent'].map(k=>[k,false])])
    assert.equal(assessRecovery({...example(),[key]:value}).status,'STOP');
});
test('each missing whole-site service stops; unknown is not unused',()=>{
  for(const key of SERVICES) {
    const x=example();x.services[key]='UNKNOWN';assert.equal(assessRecovery(x).status,'STOP');
    delete x.services[key];assert.equal(assessRecovery(x).status,'STOP');
  }
  const x=example();x.services.storage='VERIFIED_NOT_USED';x.services.realtimeAndFunctions='VERIFIED_NOT_USED';
  assert.equal(assessRecovery(x).status,'SIMULATED_REQUIREMENTS_MET');
  x.services.auth='VERIFIED_NOT_USED';assert.equal(assessRecovery(x).status,'STOP');
});
test('extra fields and approval/secret strings cannot authorize or leak into result',()=>{
  for(const input of [null,{}, {...example(),approval:true},{...example(),secret:'do-not-echo'},
    {...example(),encrypted:'true'}]) {
    const r=assessRecovery(input);assert.equal(r.status,'STOP');
    assert.ok(!JSON.stringify(r).includes('do-not-echo'));assert.equal(r.executionAllowed,false);
  }
});
