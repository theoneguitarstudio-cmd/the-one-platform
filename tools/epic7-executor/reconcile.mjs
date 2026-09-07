// Independent observer contract: compares fresh snapshots, never writer PASS flags.
import { BUDGETS, UUID, HEX, exact, insist, canonical, digest, validateManifest } from './contracts.mjs';
export function validateSnapshot(s, runId) {
  exact(s, ['runId','observerId','connectionId','capturedUTC','writerClosed','tables','unscopedDigest','catalogDigest','sequenceDigest','externalEffects']);
  insist(s.runId === runId && UUID.test(s.observerId) && UUID.test(s.connectionId) && Number.isFinite(Date.parse(s.capturedUTC)) && typeof s.writerClosed === 'boolean', 'INVALID_OBSERVER');
  insist([s.unscopedDigest,s.catalogDigest,s.sequenceDigest].every(h=>HEX.test(h)) && Number.isSafeInteger(s.externalEffects) && s.externalEffects >= 0, 'INVALID_OBSERVER');
  exact(s.tables, Object.keys(BUDGETS));
  for (const rows of Object.values(s.tables)) {
    insist(Array.isArray(rows) && rows.length <= 1000, 'INVALID_OBSERVER');
    const ids = new Set();
    for(const row of rows) {
      exact(row,['key','fingerprint']);
      insist(Array.isArray(row.key) && row.key.length > 0 && row.key.length <= 4 && row.key.every(id=>UUID.test(id)) && HEX.test(row.fingerprint), 'INVALID_OBSERVER');
      const key=canonical(row.key); insist(!ids.has(key),'DUPLICATE_OBSERVATION');ids.add(key);
    }
  }
}
export function reconcile({proof,manifest,before,after,writerId,committed}) {
  const manifestHash=validateManifest(manifest,proof);
  insist(typeof committed==='boolean','INVALID_COMMIT_STATE');
  validateSnapshot(before,manifest.runId); validateSnapshot(after,manifest.runId);
  insist(UUID.test(writerId) && before.connectionId !== writerId && after.connectionId !== writerId && before.connectionId !== after.connectionId && before.observerId !== after.observerId, 'OBSERVER_NOT_INDEPENDENT');
  insist(after.writerClosed && Date.parse(after.capturedUTC) >= Date.parse(before.capturedUTC), 'OBSERVER_TOO_EARLY');
  insist(!committed || manifest.mode === 'COMMITTED_PROPOSAL','UNAPPROVED_COMMIT');
  const problems=[]; const counts={};
  if(before.unscopedDigest !== after.unscopedDigest) problems.push('UNSCOPED_CHANGE');
  if(before.catalogDigest !== after.catalogDigest) problems.push('CATALOG_CHANGE');
  if(before.sequenceDigest !== after.sequenceDigest) problems.push('SEQUENCE_CHANGE');
  if(before.externalEffects !== 0 || after.externalEffects !== 0) problems.push('EXTERNAL_EFFECT');
  for(const table of Object.keys(BUDGETS)) {
    if(before.tables[table].length) problems.push('BASELINE_COLLISION');
    const expected=committed?manifest.tables[table].rows.map(({key,fingerprint})=>({key,fingerprint})):[];
    const sorted=rows=>[...rows].sort((a,b)=>canonical(a.key).localeCompare(canonical(b.key)));
    if(canonical(sorted(after.tables[table]))!==canonical(sorted(expected))) problems.push('UNEXPECTED_RESIDUE');
    counts[table]={expected:expected.length,actual:after.tables[table].length};
  }
  return {schema:1,mode:'SYNTHETIC_ONLY',runId:manifest.runId,manifestHash,observerIds:[before.observerId,after.observerId],
    writerId,beforeHash:digest(before),afterHash:digest(after),counts,status:problems.length?'FAIL':'PASS',reasons:[...new Set(problems)]};
}
