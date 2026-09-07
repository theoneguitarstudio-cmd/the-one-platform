import {immutable,hash,fail,tableKeys} from './schema.mjs';
import {requirePlan} from './compile.mjs';
import {observerQueries,fullTableDigestQuery,validateSnapshot} from './observe.mjs';

// This module compiles/decodes a read program. It has NO connection or execution API.
// Inputs remain untrusted observations, never a credential or formal target attestation.
const trusted=new WeakSet(), hex=/^[a-f0-9]{64}$/;
const identifier=x=>{if(typeof x!=='string'||!/^[a-z_][a-z_0-9]*$/.test(x))fail('OBSERVER_IDENTIFIER');return '"'+x+'"';};
const exact=(x,keys)=>{if(!x||JSON.stringify(Object.keys(x).sort())!==JSON.stringify([...keys].sort()))fail('OBSERVER_FIELDS');};
const digest=(rows)=>{
 if(!Array.isArray(rows)||rows.length!==1)fail('OBSERVER_CARDINALITY');
 exact(rows[0],['count','fingerprint']);
 if(typeof rows[0].count!=='string'||typeof rows[0].fingerprint!=='string'||!/^(0|[1-9][0-9]*)$/.test(rows[0].count)||BigInt(rows[0].count)>9223372036854775807n||!hex.test(rows[0].fingerprint))fail('OBSERVER_DIGEST');
 return structuredClone(rows[0]);
};
export const discoverySQL="select n.nspname as schema,c.relname as name,c.relkind::text as kind from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private') and c.relkind in ('r','p','S','f','m') order by 1,2";
// Includes ACL, RLS, columns/defaults, constraints, indexes, policies, trigger/function definitions,
// roles and extensions. Only a digest exits PostgreSQL; no function body or role details are emitted.
export const catalogSQL=String.raw`with entries as (
 select 'relation' k,to_jsonb(c)::text v from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private')
 union all select 'namespace',to_jsonb(n)::text from pg_namespace n where n.nspname in ('public','auth','private')
 union all select 'index',to_jsonb(i)::text from pg_index i join pg_class c on c.oid=i.indrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private')
 union all select 'sequence',to_jsonb(s)::text from pg_sequence s join pg_class c on c.oid=s.seqrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private')
 union all select 'default_acl',to_jsonb(a)::text from pg_default_acl a
 union all select 'column',to_jsonb(a)::text from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private') and a.attnum>0
 union all select 'default',to_jsonb(a)::text from pg_attrdef a join pg_class c on c.oid=a.adrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private')
 union all select 'constraint',to_jsonb(c)::text from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname in ('public','auth','private')
 union all select 'policy',to_jsonb(p)::text from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private')
 union all select 'trigger',to_jsonb(t)::text from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','auth','private')
 union all select 'function',to_jsonb(p)::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','auth','private')
 union all select 'role',to_jsonb(r)::text from pg_roles r
 union all select 'membership',to_jsonb(r)::text from pg_auth_members r
 union all select 'extension',to_jsonb(e)::text from pg_extension e
) select count(*)::text as count,encode(sha256(convert_to(coalesce(string_agg(k||':'||v,E'\n' order by k,v),''),'UTF8')),'hex') as fingerprint from entries`;
export function compileObserver(plan,inventory){
 requirePlan(plan);
 if(!Array.isArray(inventory)||!inventory.length||inventory.length>1000)fail('OBSERVER_INVENTORY');
 const names=new Set(),tables=[],sequences=[];
 for(const r of inventory){
  exact(r,['schema','name','kind']);identifier(r.name);
  if(!['public','auth'].includes(r.schema)||!['r','p','S'].includes(r.kind))fail('OBSERVER_UNSUPPORTED_RELATION');
  const name=r.schema+'.'+r.name;if(names.has(name))fail('OBSERVER_DUPLICATE_RELATION');names.add(name);
  (r.kind==='S'?sequences:tables).push(r);
 }
 if(Object.keys(tableKeys).some(t=>!tables.some(r=>r.schema+'.'+r.name===t)))fail('OBSERVER_MISSING_SCOPE_TABLE');
 tables.sort((a,b)=>(a.schema+'.'+a.name).localeCompare(b.schema+'.'+b.name));
 sequences.sort((a,b)=>(a.schema+'.'+a.name).localeCompare(b.schema+'.'+b.name));
 const scope=observerQueries(plan),queries=[
  {id:'identity',text:"select pg_backend_pid() as pid,current_database() as database,current_setting('epic7_f.run_id',true) as marker,current_setting('transaction_read_only') as readonly,current_setting('transaction_isolation') as isolation",values:[]},
  {id:'catalog',text:catalogSQL,values:[]},{id:'inventory',text:discoverySQL,values:[]}
 ];
 for(const r of tables){
  const name=r.schema+'.'+r.name;
  queries.push({id:'all:'+name,...fullTableDigestQuery(r.schema,r.name),values:[]});
  const scoped=scope.find(q=>q.table===name);
  if(scoped){
   // Extract only from our own branded compiler output, never SQL supplied by a caller.
   const marker=' from '+identifier(r.schema)+'.'+identifier(r.name)+' t where ';
   const offset=scoped.text.lastIndexOf(marker);
   if(offset<0||!scoped.text.endsWith(' order by 1'))fail('OBSERVER_QUERY_SHAPE');
   const predicate=scoped.text.slice(offset+marker.length,-' order by 1'.length);
   const all=fullTableDigestQuery(r.schema,r.name).text;
   queries.push({id:'unscoped:'+name,text:'with scope as (select $1::uuid[] actors,$2::uuid[] courses,$3::uuid[] skills) '+all.replace(' t) rows',' t where ('+predicate+') is not true) rows'),values:scoped.values});
   queries.push({id:'scope:'+name,text:scoped.text,values:scoped.values});
  }
 }
 for(const r of sequences)queries.push({id:'sequence:'+r.schema+'.'+r.name,
  text:'select last_value::text as last_value,is_called from '+identifier(r.schema)+'.'+identifier(r.name),values:[]});
 const program={mode:'LOCAL_SYNTHETIC_READ_PROGRAM',runId:plan.runId,planHash:plan.planHash,
  begin:"begin isolation level repeatable read read only",
  // The future driver must apply both timeouts, verify its pinned local container/database first,
  // and close this read transaction on any failure. Nothing here opens a connection.
  configure:["set local statement_timeout='10s'","set local lock_timeout='2s'"],
  queries,inventory:structuredClone(inventory),end:'rollback',productionAllowed:false,executed:false};
 immutable(program);trusted.add(program);return program;
}
export function decodeObserver(plan,program,replies,{writerId,writerClosed,at}){
 requirePlan(plan);
 if(!trusted.has(program)||program.planHash!==plan.planHash)fail('OBSERVER_PROGRAM_BINDING');
 if(!Number.isInteger(writerId)||writerId<1||typeof writerClosed!=='boolean'||!Number.isFinite(Date.parse(at)))fail('OBSERVER_CONTEXT');
 exact(replies,program.queries.map(q=>q.id));
 if(!Array.isArray(replies.inventory))fail('OBSERVER_INVENTORY');
 const canonicalInventory=x=>JSON.stringify(x.map(r=>{exact(r,['schema','name','kind']);return [r.schema,r.name,r.kind];}).sort());
 if(canonicalInventory(replies.inventory)!==canonicalInventory(program.inventory))fail('OBSERVER_INVENTORY_DRIFT');
 const identity=replies.identity;
 if(!Array.isArray(identity)||identity.length!==1)fail('OBSERVER_IDENTITY');
 const info=identity[0];exact(info,['pid','database','marker','readonly','isolation']);
 if(!Number.isInteger(info.pid)||info.pid<1||info.pid===writerId||info.database!=='epic7_race_20260906'||info.marker!==plan.runId||info.readonly!=='on'||info.isolation!=='repeatable read')fail('OBSERVER_IDENTITY');
 const allTables={},tables={},unscoped={},sequences={};
 for(const q of program.queries){
  const rows=replies[q.id];
  if(q.id.startsWith('all:'))allTables[q.id.slice(4)]=digest(rows);
  if(q.id.startsWith('unscoped:'))unscoped[q.id.slice(9)]=digest(rows);
  if(q.id.startsWith('scope:')){
   if(!Array.isArray(rows)||rows.length>10000)fail('OBSERVER_CARDINALITY');
   const table=q.id.slice(6);
   for(const row of rows)exact(row,table==='public.audit_logs'?['key','fingerprint','generated_id']:['key','fingerprint']);
   tables[table]=structuredClone(rows);
  }
  if(q.id.startsWith('sequence:')){
   if(!Array.isArray(rows)||rows.length!==1)fail('OBSERVER_CARDINALITY');
   exact(rows[0],['last_value','is_called']);
   if(typeof rows[0].last_value!=='string'||!/^(-?[1-9][0-9]*|0)$/.test(rows[0].last_value)||BigInt(rows[0].last_value)<-9223372036854775808n||BigInt(rows[0].last_value)>9223372036854775807n||typeof rows[0].is_called!=='boolean')fail('OBSERVER_SEQUENCE');
   sequences[q.id.slice(9)]=structuredClone(rows[0]);
  }
 }
 for(const [name,value] of Object.entries(allTables))if(!unscoped[name])unscoped[name]=value;
 const snapshot={runId:plan.runId,connectionId:info.pid,at,writerClosed,tables,allTables,
  catalogHash:digest(replies.catalog).fingerprint,sequenceHash:hash(sequences),unscopedHash:hash(unscoped)};
 validateSnapshot(snapshot,plan);
 // Return only reviewed fields. Driver errors, result extras, credentials and row bodies are rejected.
 return immutable({snapshot,programHash:hash(program),snapshotHash:hash(snapshot),
  mode:'DECODED_UNTRUSTED_LOCAL_OBSERVATIONS',productionEvidence:false,domainTestExecuted:false});
}
