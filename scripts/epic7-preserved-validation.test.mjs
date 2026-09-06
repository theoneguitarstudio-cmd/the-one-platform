import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {verify, main, candidate, preserved} from './epic7-preserved-validation.mjs';

test('fixed preserved set passes real CLI with network/process/env tripwires', () => {
  const r = JSON.parse(execFileSync(process.execPath, ['--import', './scripts/epic7-readiness-offline-tripwire.mjs',
    'scripts/epic7-preserved-validation.mjs', '--validate-only'], {encoding: 'utf8'}));
  assert.equal(r.validation, 'PASS'); assert.equal(r.preserved, preserved);
  assert.equal(r.candidate, candidate); assert.equal(r.executionAllowed, false);
  assert.equal(r.databaseConnections + r.sql + r.network, 0);
});
for (const args of [['--candidate', candidate], ['--candidate', '0'.repeat(40)], ['--production'], ['--production', '--yes'], ['--yes']]) {
  test('reject caller override/mode ' + args.join(' '), () => assert.rejects(main(args)));
}
for (const file of ['src/app/layout.tsx', 'supabase/migrations/20260906000500_learning_freeze_graph_validation.sql',
  'scripts/epic7-readiness.mjs', 'scripts/epic7-readiness-cases.json', 'docs/EPIC7_F_TOOLING_MANIFEST.json']) {
  test('reject modified protected content ' + file, () => assert.rejects(verify({read(p, ...a) {
    return String(p).replaceAll('\\', '/').endsWith(file) ? Buffer.from('tampered') : readFileSync(p, ...a);
  }}), /Protected content mismatch/));
}
test('candidate object bytes cannot be replaced even with correct claimed SHA', () => assert.rejects(verify({read(p, ...a) {
  if (String(p).replaceAll('\\', '/').endsWith(candidate.slice(0, 2) + '/' + candidate.slice(2))) {
    return readFileSync(String(p).replace(candidate.slice(0, 2) + '\\' + candidate.slice(2), preserved.slice(0, 2) + '\\' + preserved.slice(2)), ...a);
  }
  return readFileSync(p, ...a);
}}), /hash mismatch/));
test('missing object never falls back to network or current HEAD', () => assert.rejects(verify({read(p, ...a) {
  if (String(p).includes('objects')) throw Error('missing');
  return readFileSync(p, ...a);
}}), /unavailable/));
