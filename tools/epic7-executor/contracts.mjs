// Review-only executor contracts. No production transport, credentials or SQL.
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync, readdirSync, lstatSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
export const TARGET = Object.freeze({ name: 'the-one-platform', ref: 'ygxeihtcolpiulupieeq', region: 'ap-southeast-1' });
export const CANDIDATE = 'd5f98434106797afc65c59953aa3bc61ba26ecb4';
const VERIFIER_HASH = 'f0394a2b0732a2de5e41aeaf57e73ca6ff4f53c6cb8d4fc28ef4732e6f82c74f';
export const UUID = /^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/;
export const HEX = /^[a-f0-9]{64}$/;
export const TOOL_FILES = Object.freeze(['contracts.mjs', 'reconcile.mjs', 'simulate.mjs', 'safety.test.mjs']);
const proofs = new WeakSet();
const proofFiles = new WeakMap();
export const sha = bytes => createHash('sha256').update(bytes).digest('hex');
export function canonical(value) {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value && typeof value === 'object') return '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + canonical(value[k])).join(',') + '}';
  return JSON.stringify(value);
}
export const digest = value => sha(canonical(value));
export class Stop extends Error { constructor(code) { super(code); this.code = code; } }
export function insist(ok, code) { if (!ok) throw new Stop(code); }
export function exact(value, keys, code = 'INVALID_SHAPE') {
  insist(value && Object.getPrototypeOf(value) === Object.prototype && canonical(Object.keys(value).sort()) === canonical([...keys].sort()), code);
}
export function freeze(value) {
  if (value && typeof value === 'object') { Object.values(value).forEach(freeze); Object.freeze(value); }
  return value;
}
// Fixed original verifier remains the trust root, never a supplied SHA/receipt.
export async function proveLocalContent() {
  insist(sha(readFileSync(resolve(ROOT, 'scripts/epic7-preserved-validation.mjs'))) === VERIFIER_HASH, 'VERIFIER_DRIFT');
  const old = await import('../../scripts/epic7-preserved-validation.mjs');
  const result = await old.verify(); // Required integration check for this NEW executor, not a migration rerun.
  insist(result.validation === 'PASS' && result.candidate === CANDIDATE && result.executionAllowed === false, 'CONTENT_DRIFT');
  const files = old.snapshot();
  const manifest = JSON.parse(files.get('docs/EPIC7_F_TOOLING_MANIFEST.json'));
  const code = [...files].filter(([p]) => !p.startsWith('docs/') && !p.startsWith('scripts/') && !p.startsWith('supabase/') && !p.startsWith('.env'));
  const toolDir = resolve(ROOT, 'tools/epic7-executor');
  insist(canonical(readdirSync(toolDir).sort()) === canonical([...TOOL_FILES].sort()), 'UNREVIEWED_TOOL_FILE');
  const executorHashes = Object.fromEntries(TOOL_FILES.map(p => {
    insist(lstatSync(resolve(toolDir, p)).isFile() && !lstatSync(resolve(toolDir, p)).isSymbolicLink(), 'TOOL_LINK');
    return [p, sha(readFileSync(resolve(toolDir, p)))];
  }));
  const reviewPath='docs/EPIC7_EXECUTOR_REVIEW_MANIFEST.json';
  const review=JSON.parse(readFileSync(resolve(ROOT,reviewPath)));
  exact(review,['format','candidate','status','files']);
  insist(review.format===1 && review.candidate===CANDIDATE && review.status==='REVIEW_REQUIRED' && canonical(review.files)===canonical(executorHashes),'EXECUTOR_REVIEW_DRIFT');
  const proof = freeze({ reviewManifestHash:sha(readFileSync(resolve(ROOT,reviewPath))), candidate: CANDIDATE, preserved: old.preserved, verifierHash: VERIFIER_HASH,
    applicationHash: digest(Object.fromEntries(code.map(([p,b]) => [p,sha(b)]))),
    migrations: manifest.migrations, historicalToolHashes: manifest.files, executorHashes,
    caseIds: JSON.parse(files.get('scripts/epic7-readiness-cases.json')).map(c => c.id) });
  const protectedFiles = [...files.keys()].filter(p => !p.startsWith("docs/") && !p.startsWith(".env"));
  protectedFiles.push(reviewPath, "docs/EPIC7_F_TOOLING_MANIFEST.json", "scripts/epic7-preserved-validation.mjs", "scripts/epic7-preserved-validation.test.mjs", ...TOOL_FILES.map(p => "tools/epic7-executor/" + p));
  proofFiles.set(proof, new Map(protectedFiles.map(p => [p, sha(readFileSync(resolve(ROOT,p)))])));
  proofs.add(proof);
  return proof;
}
export function requireProof(proof) { insist(proofs.has(proof), 'UNPROVEN_VERSION'); }
export function assertCurrentContent(proof) {
  requireProof(proof);
  const expected = proofFiles.get(proof);
  for (const [p,h] of expected) insist(sha(readFileSync(resolve(ROOT,p))) === h, 'CONTENT_DRIFT');
  const walk = dir => {
    for (const name of readdirSync(resolve(ROOT,dir))) {
      const p=dir+'/'+name, stat=lstatSync(resolve(ROOT,p));
      insist(!stat.isSymbolicLink(), 'TOOL_LINK');
      if(stat.isDirectory())walk(p);else insist(expected.has(p),'UNREVIEWED_TOOL_FILE');
    }
  };
  for(const dir of ['src','public','scripts','tests','supabase/migrations','supabase/tests','tools/epic7-executor'])walk(dir);
}
export function checkAttestation(proof, observed, runId, now = Date.now()) {
  requireProof(proof);
  exact(observed, ['source','runId','observedUTC','target','candidate','latest','migrations','applicationHash','historicalToolHashes','executorHashes','authority']);
  insist(observed.source === 'SYNTHETIC_ONLY', 'LIVE_ATTESTATION_UNAVAILABLE');
  insist(observed.runId === runId, 'WRONG_RUN');
  const at = Date.parse(observed.observedUTC);
  insist(Number.isFinite(at) && at <= now && now - at <= 300000, 'STALE_ATTESTATION');
  insist(canonical(observed.target) === canonical(TARGET), 'WRONG_TARGET');
  insist(observed.candidate === proof.candidate, 'WRONG_VERSION');
  insist(observed.latest === '20260906000500' && Object.keys(observed.migrations).length === 34 && canonical(observed.migrations) === canonical(proof.migrations), 'MIGRATION_DRIFT');
  insist(observed.applicationHash === proof.applicationHash, 'APPLICATION_DRIFT');
  insist(canonical(observed.historicalToolHashes) === canonical(proof.historicalToolHashes) && canonical(observed.executorHashes) === canonical(proof.executorHashes), 'TOOL_DRIFT');
  insist(observed.authority === 'SHIPPED_FALSE', 'AUTHORITY_DRIFT');
}

// Proposal ceilings copied from the existing coverage contract, NOT approved production allocations.
export const BUDGETS = freeze({ 'auth.users':12, 'public.profiles':12, 'public.user_roles':24,
  'public.system_courses':2, 'public.learning_maps':2, 'public.curriculum_publications':4,
  'public.curriculum_stages':4, 'public.learning_modules':6, 'public.learning_nodes':8,
  'public.curriculum_stage_versions':8, 'public.learning_module_versions':12, 'public.learning_node_versions':16,
  'public.learning_resources':10, 'public.learning_resource_versions':20, 'public.learning_node_resources':40,
  'public.learning_objectives':8, 'public.learning_objective_versions':16, 'public.learning_objective_skills':16,
  'public.learning_skills':4, 'public.content_contributors':4, 'public.learning_author_credits':16,
  'public.learning_capabilities':8, 'public.learning_node_capability_attachments':16, 'public.learning_node_prerequisites':16,
  'public.learning_mutation_receipts':64, 'public.audit_logs':64, 'public.learning_self_activity':16, 'public.learning_activity_requests':32 });
export function validateManifest(manifest, proof) {
  requireProof(proof);
  exact(manifest, ['format','runId','candidate','target','mode','approval','cases','actors','scopes','tables','retention','label']);
  insist(manifest.format === 1 && UUID.test(manifest.runId) && manifest.candidate === CANDIDATE && canonical(manifest.target) === canonical(TARGET), 'MANIFEST_IDENTITY');
  insist(manifest.approval === 'NOT_APPROVED' && ['ROLLBACK','COMMITTED_PROPOSAL'].includes(manifest.mode), 'NO_EXECUTION_AUTHORITY');
  insist(manifest.label === 'epic7-synthetic-' + manifest.runId, 'INVALID_LABEL');
  exact(manifest.retention, ['decision','custodian','until','disposal']);
  insist(canonical(manifest.retention) === canonical({decision:'PENDING',custodian:'UNKNOWN',until:'UNKNOWN',disposal:'NO_DELETE_OR_REPAIR'}), 'UNAPPROVED_RETENTION');
  insist(Array.isArray(manifest.cases) && manifest.cases.length > 0 && manifest.cases.length <= 37, 'INVALID_CASES');
  const ids = new Set();
  for (const c of manifest.cases) {
    exact(c, ['id','branch']);
    insist(proof.caseIds.includes(c.id) && !ids.has(c.id), 'INVALID_CASES'); ids.add(c.id);
    if (['P04','P05','P06','R04'].includes(c.id)) insist(c.branch === 'denial', 'POSITIVE_AUTHORITY_BLOCKED');
    else insist(c.branch === 'shipped', 'INVALID_BRANCH');
    if (/^R0[1-4]$/.test(c.id)) insist(manifest.mode === 'COMMITTED_PROPOSAL', 'CROSS_SESSION_NEEDS_COMMIT');
  }
  insist(Array.isArray(manifest.actors) && manifest.actors.length > 0 && manifest.actors.length <= 12, 'INVALID_ACTORS');
  const actors = new Set();
  for (const a of manifest.actors) {
    exact(a, ['id','alias','role','state']);
    insist(UUID.test(a.id) && !actors.has(a.id), 'DUPLICATE_ACTOR'); actors.add(a.id);
    insist(a.alias === 'synthetic-' + a.id && ['admin','super_admin','teacher','creator','student'].includes(a.role) && ['active','inactive','role_removed'].includes(a.state), 'INVALID_ACTOR');
  }
  insist(Array.isArray(manifest.scopes) && manifest.scopes.length > 0 && manifest.scopes.length <= 2, 'INVALID_SCOPES');
  const allIds = new Set(actors), courses = new Map();
  for (const s of manifest.scopes) {
    exact(s, ['course','map','versions','nodes']);
    insist(Array.isArray(s.versions) && s.versions.length > 0 && s.versions.length <= 2 && Array.isArray(s.nodes) && s.nodes.length > 0 && s.nodes.length <= 4, 'INVALID_SCOPES');
    for (const id of [s.course,s.map,...s.versions,...s.nodes]) { insist(UUID.test(id) && !allIds.has(id), 'DUPLICATE_ID'); allIds.add(id); }
    courses.set(s.course, s);
  }
  exact(manifest.tables, Object.keys(BUDGETS));
  const keys = new Set();
  for (const [table, limit] of Object.entries(BUDGETS)) {
    const plan = manifest.tables[table]; exact(plan, ['ceiling','rows','expectedRetained']);
    insist(plan.ceiling === limit && Array.isArray(plan.rows) && plan.rows.length <= limit, 'BUDGET_EXCEEDED');
    insist(plan.expectedRetained === (manifest.mode === 'ROLLBACK' ? 0 : plan.rows.length), 'RETENTION_COUNT');
    if (['public.learning_self_activity','public.learning_activity_requests'].includes(table)) insist(plan.rows.length === 0, 'POSITIVE_AUTHORITY_BLOCKED');
    for (const row of plan.rows) {
      exact(row, ['key','actor','course','map','version','node','caseId','label','fingerprint']);
      insist(Array.isArray(row.key) && row.key.length > 0 && row.key.length <= 4 && row.key.every(id => UUID.test(id)), 'INVALID_KEY');
      const k = table + ':' + canonical(row.key); insist(!keys.has(k), 'DUPLICATE_ROW'); keys.add(k);
      insist(actors.has(row.actor) && ids.has(row.caseId) && row.label === manifest.label && HEX.test(row.fingerprint), 'INVALID_ROW');
      const scope = courses.get(row.course);
      insist(scope && scope.map === row.map && scope.versions.includes(row.version) && (row.node === null || scope.nodes.includes(row.node)), 'CROSS_SCOPE_ROW');
    }
  }
  insist(keys.size > 0, 'EMPTY_FIXTURE');
  insist(manifest.tables['public.system_courses'].rows.length > 0, 'MISSING_SENTINEL_FIXTURE');
  return digest(manifest);
}

// Example is a transport-independent identity inventory, NOT SQL or a complete 37-case fixture.
export function exampleManifest(mode = 'ROLLBACK', cases = [{id:'H01',branch:'shipped'}]) {
  const runId = randomUUID(), label = 'epic7-synthetic-' + runId;
  const actors = ['admin','super_admin','teacher','creator','student','student'].map(role => { const id=randomUUID(); return {id,alias:'synthetic-'+id,role,state:'active'}; });
  const scopes = Array.from({length:2}, () => ({course:randomUUID(),map:randomUUID(),versions:[randomUUID(),randomUUID()],nodes:Array.from({length:4},()=>randomUUID())}));
  const tables = Object.fromEntries(Object.entries(BUDGETS).map(([t,ceiling]) => [t,{ceiling,rows:[],expectedRetained:0}]));
  const add = (table,key,s,actor=actors[0].id) => tables[table].rows.push({key:[key],actor,course:s.course,map:s.map,version:s.versions[0],node:null,caseId:cases[0].id,label,fingerprint:digest({synthetic:key,table})});
  for (const a of actors) { add('auth.users',a.id,scopes[0],a.id); add('public.profiles',a.id,scopes[0],a.id); }
  for (const s of scopes) {
    add('public.system_courses',s.course,s); add('public.learning_maps',s.map,s);
    for(const v of s.versions) add('public.curriculum_publications',v,s);
    for(const n of s.nodes) add('public.learning_nodes',n,s);
    add('public.learning_mutation_receipts',randomUUID(),s); add('public.audit_logs',randomUUID(),s);
  }
  for(const t of Object.values(tables)) t.expectedRetained = mode === 'ROLLBACK' ? 0 : t.rows.length;
  return {format:1,runId,candidate:CANDIDATE,target:{...TARGET},mode,approval:'NOT_APPROVED',cases,actors,scopes,tables,label,
    retention:{decision:'PENDING',custodian:'UNKNOWN',until:'UNKNOWN',disposal:'NO_DELETE_OR_REPAIR'}};
}
