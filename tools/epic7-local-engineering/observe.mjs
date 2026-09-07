import {hash,immutable,tableKeys,fail} from './schema.mjs';
import {requirePlan} from './compile.mjs';
const ident=s=>{if(!/^[a-z_][a-z_0-9]*$/.test(s))fail('INVALID_IDENTIFIER');return '"'+s+'"';};
export const inventoryQuery="select n.nspname as schema,c.relname as name from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth') and c.relkind in ('r','p') order by 1,2";
export function observerQueries(plan){
 requirePlan(plan);
 return immutable(Object.entries(tableKeys).map(([table,keys])=>{
  const name=table.split('.').map(ident).join('.');
  const keySql=keys.map(k=>k==='request_id'&&table==='public.audit_logs'?"t.after_snapshot->>'request_id'":'t.'+ident(k)+'::text');
  // Read all run-related rows, not just predicted keys, so extra children/receipts cannot hide.
  const actors=Object.values(plan.actors), courseIds=plan.rows['public.system_courses'].keys.map(k=>k[0]);
  let predicate;
  if(table==='auth.users')predicate='t.id=any($1::uuid[])';
  else if(['public.profiles','public.user_roles'].includes(table))predicate='t.user_id=any($1::uuid[])';
  else if(table==='public.audit_logs')predicate='t.actor_user_id=any($1::uuid[])';
  else if(table==='public.system_courses')predicate='t.id=any($2::uuid[])';
  else if(['public.learning_self_activity','public.learning_activity_requests'].includes(table))predicate='t.subject_id=any($1::uuid[])';
  else if(table==='public.learning_mutation_receipts')predicate='t.actor_id=any($1::uuid[])';
  else if(table==='public.content_contributors')predicate='t.auth_user_id=any($1::uuid[])';
  else if(table==='public.learning_skills')predicate='t.id=any($3::uuid[])';
  else if(['public.learning_objective_skills','public.learning_node_prerequisites'].includes(table))
   predicate='t.publication_id in (select id from public.curriculum_publications where course_id=any($2::uuid[]))';
  else predicate='t.course_id=any($2::uuid[])';
  return {table,text:'with scope as (select $1::uuid[] actors,$2::uuid[] courses,$3::uuid[] skills) select jsonb_build_array('+keySql.join(',')+") as key, encode(sha256(convert_to(to_jsonb(t)::text,'UTF8')),'hex') as fingerprint"
   +(table==='public.audit_logs'?', t.id::text as generated_id':'')+' from '+name+' t where '+predicate+' order by 1',
   // All three parameters must be typed in the text, even when an individual predicate omits one.
   values:[actors,courseIds,plan.rows['public.learning_skills'].keys.map(k=>k[0])]};
 }));
}
export function fullTableDigestQuery(schema,name){
 if(!['public','auth'].includes(schema))fail('UNREVIEWED_SCHEMA');
 return {text:"select count(*)::text as count, encode(sha256(convert_to(coalesce(string_agg(h,',' order by h),''),'UTF8')),'hex') as fingerprint from (select encode(sha256(convert_to(to_jsonb(t)::text,'UTF8')),'hex') h from "+ident(schema)+'.'+ident(name)+' t) rows'};
}
const hex=/^[a-f0-9]{64}$/;
export function validateSnapshot(s,plan){
 if(!s||s.runId!==plan.runId||!Number.isInteger(s.connectionId)||s.connectionId<1||!Number.isFinite(Date.parse(s.at)))fail('OBSERVER_IDENTITY');
 if(JSON.stringify(Object.keys(s.tables).sort())!==JSON.stringify(Object.keys(tableKeys).sort()))fail('OBSERVER_TABLES');
 for(const [table,rows] of Object.entries(s.tables)){
  if(!Array.isArray(rows))fail('OBSERVER_ROWS');
  const seen=new Set();
  for(const r of rows){
   if(!Array.isArray(r.key)||r.key.length!==tableKeys[table].length||r.key.some(v=>v!==null&&typeof v!=='string')||!hex.test(r.fingerprint))fail('OBSERVER_ROW');
   const key=JSON.stringify(r.key);if(seen.has(key))fail('DUPLICATE_OBSERVER_KEY');seen.add(key);
   if(table==='public.audit_logs'&&!/^[a-f0-9-]{36}$/.test(r.generated_id??''))fail('AUDIT_PK_MISSING');
  }
 }
 if(!s.catalogHash||!hex.test(s.catalogHash)||!hex.test(s.sequenceHash)||!s.allTables||!Object.keys(s.allTables).length)fail('INCOMPLETE_BASELINE');
 for(const r of Object.values(s.allTables))if(!/^\d+$/.test(r.count)||!hex.test(r.fingerprint))fail('INVALID_DIGEST');
}
export function reconcile(plan,before,after,writerId){
 requirePlan(plan);const reasons=[];
 try{
  validateSnapshot(before,plan);validateSnapshot(after,plan);
  if(before.connectionId===writerId||after.connectionId===writerId||before.connectionId===after.connectionId)fail('OBSERVER_NOT_INDEPENDENT');
  if(after.writerClosed!==true||Date.parse(after.at)<Date.parse(before.at))fail('WRITER_NOT_CLOSED');
  if(Object.values(before.tables).some(rows=>rows.length))fail('FIXTURE_COLLISION');
  // This increment deliberately accepts rollback-only reconciliation. Race retention cannot use it.
  if(plan.races)fail('COMMITTED_OBSERVER_REQUIRES_RETENTION');
  if(Object.values(after.tables).some(rows=>rows.length))fail('UNEXPECTED_RESIDUE');
  if(JSON.stringify(before.allTables)!==JSON.stringify(after.allTables))fail('UNSCOPED_CHANGE');
  if(before.catalogHash!==after.catalogHash)fail('CATALOG_CHANGE');
  if(before.sequenceHash!==after.sequenceHash)fail('SEQUENCE_CHANGE');
 }catch(e){reasons.push(['OBSERVER_IDENTITY','OBSERVER_TABLES','OBSERVER_ROWS','OBSERVER_ROW','DUPLICATE_OBSERVER_KEY','AUDIT_PK_MISSING','INCOMPLETE_BASELINE','INVALID_DIGEST','OBSERVER_NOT_INDEPENDENT','WRITER_NOT_CLOSED','FIXTURE_COLLISION','COMMITTED_OBSERVER_REQUIRES_RETENTION','UNEXPECTED_RESIDUE','UNSCOPED_CHANGE','CATALOG_CHANGE','SEQUENCE_CHANGE'].includes(e.message)?e.message:'INVALID_OBSERVER');}
 return immutable({mode:'OFFLINE_CONTROL_TEST',runId:plan.runId,planHash:plan.planHash,status:reasons.length?'FAIL':'PASS',
  reasons,beforeHash:hash(before??null),afterHash:hash(after??null),productionEvidence:false});
}

export function reconcileCommitted(plan,before,after,confirmation,writerId){
 requirePlan(plan);const stop=[];
 try{
  if(!plan.races)fail('NOT_COMMITTED_PLAN');
  for(const s of [before,after,confirmation])validateSnapshot(s,plan);
  if(new Set([writerId,before.connectionId,after.connectionId,confirmation.connectionId]).size!==4)fail('OBSERVER_NOT_INDEPENDENT');
  if(!after.writerClosed||!confirmation.writerClosed||Date.parse(after.at)<Date.parse(before.at)||Date.parse(confirmation.at)<Date.parse(after.at))fail('WRITER_NOT_CLOSED');
  if(Object.values(before.tables).some(r=>r.length))fail('FIXTURE_COLLISION');
  for(const t of Object.keys(tableKeys)){
   const expected=plan.rows[t].keys.map(k=>JSON.stringify(k)).sort();
   const actual=after.tables[t].map(r=>JSON.stringify(r.key)).sort();
   if(JSON.stringify(expected)!==JSON.stringify(actual))fail('RETAINED_KEYS_MISMATCH');
   const stable=s=>s.tables[t].map(r=>JSON.stringify(r)).sort();
   if(JSON.stringify(stable(after))!==JSON.stringify(stable(confirmation)))fail('RETAINED_CONTENT_CHANGED');
  }
  const names=Object.keys(before.allTables).sort();
  for(const s of [after,confirmation]){
   if(JSON.stringify(Object.keys(s.allTables).sort())!==JSON.stringify(names))fail('OBSERVER_TABLES');
   if(s.catalogHash!==before.catalogHash||s.sequenceHash!==before.sequenceHash)fail('CATALOG_OR_SEQUENCE_CHANGE');
   if(!hex.test(s.unscopedHash??'')||s.unscopedHash!==before.unscopedHash)fail('UNSCOPED_CHANGE');
   for(const t of names){
    const delta=plan.rows[t]?.count??0;
    if(BigInt(s.allTables[t].count)!==BigInt(before.allTables[t].count)+BigInt(delta))fail('RETAINED_COUNT_MISMATCH');
    if(!delta&&s.allTables[t].fingerprint!==before.allTables[t].fingerprint)fail('UNSCOPED_CHANGE');
   }
  }
  for(const [table,r] of Object.entries(plan.rows))if(r.count&&!names.includes(table))fail('OBSERVER_TABLES');
 }catch(e){stop.push(['NOT_COMMITTED_PLAN','OBSERVER_NOT_INDEPENDENT','WRITER_NOT_CLOSED','FIXTURE_COLLISION','RETAINED_KEYS_MISMATCH','RETAINED_CONTENT_CHANGED','OBSERVER_TABLES','CATALOG_OR_SEQUENCE_CHANGE','UNSCOPED_CHANGE','RETAINED_COUNT_MISMATCH'].includes(e.message)?e.message:'INVALID_OBSERVER');}
 return immutable({mode:'ISOLATED_COMMIT_PROPOSAL_RECONCILIATION',runId:plan.runId,status:stop.length?'FAIL':'PASS',stop,
   beforeHash:hash(before??null),afterHash:hash(after??null),confirmationHash:hash(confirmation??null),
   productionEvidence:false,executionAllowed:false,cleanupAllowed:false});
}
