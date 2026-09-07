import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
export const root=new URL('../../',import.meta.url);
export const hash=x=>createHash('sha256').update(typeof x==='string'||Buffer.isBuffer(x)?x:JSON.stringify(x)).digest('hex');
export const candidate='d5f98434106797afc65c59953aa3bc61ba26ecb4';
export const fail=code=>{throw new Error(code);};
export function immutable(x){if(x&&typeof x==='object'){Object.values(x).forEach(immutable);Object.freeze(x);}return x;}
export const tableKeys=immutable({
 'auth.users':['id'],'public.profiles':['user_id'],'public.user_roles':['user_id','role'],
 'public.system_courses':['id'],'public.learning_maps':['id'],'public.curriculum_publications':['id'],
 'public.curriculum_stages':['id'],'public.learning_modules':['id'],'public.learning_nodes':['id'],
 'public.curriculum_stage_versions':['publication_id','id'],'public.learning_module_versions':['publication_id','id'],
 'public.learning_node_versions':['publication_id','id'],'public.learning_resources':['id'],
 'public.learning_resource_versions':['id'],'public.learning_node_resources':['publication_id','id'],
 'public.learning_objectives':['id'],'public.learning_objective_versions':['publication_id','id'],
 'public.learning_skills':['id'],'public.learning_objective_skills':['publication_id','objective_id','skill_id'],
 'public.learning_node_prerequisites':['publication_id','dependent_node_id','prerequisite_node_id'],
 'public.content_contributors':['id'],'public.learning_author_credits':['publication_id','id'],
 'public.learning_capabilities':['id'],'public.learning_node_capability_attachments':['publication_id','id'],
 'public.learning_mutation_receipts':['publication_id','actor_id','request_id'],
 'public.learning_self_activity':['subject_id','publication_id','node_id'],
 'public.learning_activity_requests':['subject_id','request_id'],
 // Generated audit UUID is reconciled by actual PK separately; this unique run predicate is not its PK.
 'public.audit_logs':['actor_user_id','action','target_id','request_id']
});
export function sourceIdentity(){
 const manifest=JSON.parse(readFileSync(new URL('docs/EPIC7_F_TOOLING_MANIFEST.json',root),'utf8'));
 if(manifest.candidate!==candidate)fail('CANDIDATE_DRIFT');
 const entries=Object.entries(manifest.migrations);
 if(entries.length!==34)fail('MIGRATION_COUNT');
 const actual=readdirSync(new URL('supabase/migrations/',root)).filter(p=>p.endsWith('.sql')).sort();
 const hashes={};
 for(const [path,expected] of entries){
   const p=path.startsWith('supabase/')?path:'supabase/migrations/'+path;
   const bytes=readFileSync(new URL(p,root));const h=hash(bytes);
   if(h.toLowerCase()!==expected.toLowerCase())fail('MIGRATION_HASH');
   hashes[p]=h;
 }
 if(JSON.stringify(actual)!==JSON.stringify(Object.keys(hashes).map(p=>p.split('/').at(-1)).sort()))fail('MIGRATION_FILES');
 return immutable({candidate,migrations:hashes,sourceHash:hash(hashes),scope:'LOCAL_SOURCE_ONLY',deploymentVerified:false});
}

export function functionContracts(){
 const identity=sourceIdentity(), signatures=new Map();
 for(const path of Object.keys(identity.migrations).sort()){
  const sql=readFileSync(new URL(path,root),'utf8');
  for(const m of sql.matchAll(/create\s+(?:or\s+replace\s+)?function\s+((?:public|private)\.learning_\w+)\s*\(([^)]*)\)\s*returns\s+([\s\S]*?)\$\$/gi)){
   const args=m[2].trim()?m[2].split(',').map(p=>p.trim().split(/\s+/)[1]).join(','):'';
   signatures.set(m[1]+'('+args+')',{signature:m[1]+'('+args+')',securityDefiner:/security definer/i.test(m[3]),trigger:/^trigger\b/i.test(m[3])});
  }
 }
 if(signatures.size<20)fail('FUNCTION_SOURCE_CONTRACT');
 return immutable([...signatures.values()]);
}
