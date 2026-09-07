import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {CASES,classifyCase} from '../epic7-owner-policy.mjs';
import {BUDGETS} from '../epic7-executor/contracts.mjs';
import {root,hash,immutable,fail,tableKeys,sourceIdentity,functionContracts} from './schema.mjs';
const trusted=new WeakSet();
export function requirePlan(p){if(!trusted.has(p))fail('UNTRUSTED_PLAN');}
const q=(text,values=[],expect={kind:'rows',count:1})=>({text,values:structuredClone(values),expect:structuredClone(expect)});
const legacy={
 L01:['teacher_public_discovery_rls.test.sql','teacher_security_fix_rls.test.sql','student_teacher_trial_flow_rls.test.sql','trial_security_hardening.test.sql'],
 L02:['commerce_products_orders_payments.test.sql','commerce_security_hardening.test.sql','commerce_service_role_authority.test.sql'],
 L03:['entitlement_lesson_credits.test.sql','consume_lesson_credit_teacher_role.test.sql','entitlement_revoke_booking_consistency_contract.test.sql','entitlement_revoke_idempotency.test.sql'],
 L04:['scheduling_booking_core.test.sql','makeup_booking_lifecycle.test.sql','schedule_locking_contract.test.sql','fixed_renewal_lifecycle_contract.test.sql']
};
export function compileCase(caseId){
 if(!CASES.includes(caseId))fail('UNKNOWN_CASE');
 const runId=randomUUID(), ids=new Map(), id=name=>{if(!ids.has(name))ids.set(name,randomUUID());return ids.get(name);};
 const identity=sourceIdentity(), route=classifyCase(caseId);
 const inventory=Object.fromEntries(Object.keys(tableKeys).map(t=>[t,new Map()]));
 const steps=[], checkpoints=[];
 const add=(t,key)=>{if(!inventory[t])fail('UNMAPPED_TABLE');inventory[t].set(JSON.stringify(key),key);};
 const mark=label=>checkpoints.push({label,afterStep:steps.length,counts:Object.fromEntries(Object.entries(inventory).map(([t,k])=>[t,k.size]))});
 const command=(label,actor,query)=>{steps.push({label,actor,query});};
 const rpc=(label,fn,args,casts,result,actor='admin',error=null)=>{
   command(label,actor,q('select public.'+fn+'('+casts.map((t,i)=>'$'+(i+1)+'::'+t).join(',')+') as value',args,
     error?{kind:'error',code:error[0],message:error[1]}:{kind:'scalar',value:result}));
 };
 const audit=(action,target,key=null)=>add('public.audit_logs',[id('admin'),action,target,key]);
 const mutation=(label,kind,v,rev,payload,error=null,keyName=label,actor='admin')=>{
   const key=id('request-'+keyName), fn=kind==='freeze'?'learning_freeze_version':kind==='structure'?'learning_put_structure':'learning_put_content';
   rpc(label,fn,kind==='freeze'?[v,rev,key]:[v,rev,key,payload],
     kind==='freeze'?['uuid','integer','uuid']:['uuid','integer','uuid','jsonb'],rev+1,actor,error);
   if(!error){add('public.learning_mutation_receipts',[v,id(actor),key]);audit('learning.'+kind,v,key);}
 };
 const structure=prefix=>({
  levels:(prefix==='b'?[0]:[0,1]).map(n=>({id:id(prefix+'-stage'+n),slug:'stage-'+n+'-'+runId,position:n+1,title:'Synthetic orientation '+n})),
  modules:(prefix==='b'?[0]:[0,1,2]).map(n=>({id:id(prefix+'-module'+n),slug:'module-'+n+'-'+runId,stage_id:id(prefix+'-stage'+(n===2?1:0)),position:n===1?2:1,title:'Synthetic practice '+n})),
  nodes:(prefix==='b'?[0]:[0,1,2,3]).map(n=>({id:id(prefix+'-node'+n),slug:'node-'+n+'-'+runId,module_id:id(prefix+'-module'+(n<2?0:n-1)),position:n===1?2:1,title:'Synthetic ability '+n}))
 });
 const content=prefix=>({
  resources:(prefix==='b'?[0]:[0,1,2,3]).map(n=>({id:id(prefix+'-resource'+n),slug:'resource-'+n+'-'+runId,revision_id:id(prefix+'-resource-version'+n),kind:'text',title:'Synthetic guide',content:'Synthetic local review only'})),
  links:(prefix==='b'?[0]:[0,1,2,3]).map(n=>({id:id(prefix+'-link'+n),node_id:id(prefix+'-node'+n),resource_revision_id:id(prefix+'-resource-version'+n),position:1,purpose:'practice'})),
  objectives:(prefix==='b'?[0]:[0,1,2,3]).map(n=>({id:id(prefix+'-objective'+n),node_id:id(prefix+'-node'+n),objective:'Demonstrate synthetic ability'})),
  skills:[{id:id('skill'),code:'synthetic-'+runId,definition:'Synthetic shared skill'}],
  mappings:[{objective_id:id(prefix+'-objective0'),skill_id:id('skill')}],
  contributors:[{id:id('contributor'),display_credit:'Synthetic Creator',auth_user_id:id('creator')},{id:id('teacher-credit'),display_credit:'Synthetic Teacher',auth_user_id:id('teacher')}],
  credits:[{id:id(prefix+'-credit'),contributor_id:id('contributor'),resource_revision_id:id(prefix+'-resource-version0'),contribution:'author',position:1},{id:id(prefix+'-credit-teacher'),contributor_id:id('teacher-credit'),resource_revision_id:id(prefix+'-resource-version0'),contribution:'editor',position:2}],
  capabilities:[{id:id(prefix+'-capability'),node_id:id(prefix+'-node0'),code:'async_review',description:'Metadata only'}],
  prerequisites:[]
 });
 function accountContent(prefix,v,c){
  const array=(name)=>c[name]??[];
  for(const r of array('resources')){add('public.learning_resources',[r.id]);add('public.learning_resource_versions',[r.revision_id]);}
  for(const r of array('links'))add('public.learning_node_resources',[v,r.id]);
  for(const r of array('objectives')){add('public.learning_objectives',[r.id]);add('public.learning_objective_versions',[v,r.id]);}
  for(const r of array('skills'))add('public.learning_skills',[r.id]);
  for(const r of array('mappings'))add('public.learning_objective_skills',[v,r.objective_id,r.skill_id]);
  for(const r of array('contributors'))add('public.content_contributors',[r.id]);
  for(const r of array('credits'))add('public.learning_author_credits',[v,r.id]);
  for(const r of array('capabilities')){add('public.learning_capabilities',[r.id]);add('public.learning_node_capability_attachments',[v,r.id]);}
  for(const r of array('prerequisites'))add('public.learning_node_prerequisites',[v,r.dependent_node_id,r.prerequisite_node_id]);
 }
 function draft(prefix,suffix=''){
   const v=id(prefix+'-version'+suffix);
   rpc('draft-'+prefix+suffix,'learning_create_draft',[id(prefix+'-map'),v],['uuid','uuid'],v);
   add('public.curriculum_publications',[v]);audit('learning.draft.created',v);return v;
 }
 function putStructure(prefix,v,rev=0,data=structure(prefix),label='structure-'+prefix){
  mutation(label,'structure',v,rev,data);
  for(const [name,stable,versioned] of [['levels','curriculum_stages','curriculum_stage_versions'],['modules','learning_modules','learning_module_versions'],['nodes','learning_nodes','learning_node_versions']])
   for(const row of data[name]??[]){add('public.'+stable,[row.id]);add('public.'+versioned,[v,row.id]);}
 }
 function putContent(prefix,v,rev=1,data=content(prefix),label='content-'+prefix){
  mutation(label,'content',v,rev,data);accountContent(prefix,v,data);
 }
 function create(prefix,stage='full'){
  const course=id(prefix+'-course'),map=id(prefix+'-map');
  rpc('course-'+prefix,'learning_create_course',[course,'course-'+prefix+'-'+runId,'Synthetic course',map,'map-'+runId],['uuid','text','text','uuid','text'],map);
  add('public.system_courses',[course]);add('public.learning_maps',[map]);audit('learning.course.created',course);
  const v=draft(prefix);if(stage!=='empty')putStructure(prefix,v);if(stage==='full'||stage==='frozen')putContent(prefix,v);
  if(stage==='frozen')mutation('freeze-'+prefix,'freeze',v,2);
  return v;
 }
 const assertSQL=(label,text,values,expected)=>command(label,'observer',q(text,values,{kind:'scalar',value:expected}));
 let v;
 let status='COMPILED_NOT_EXECUTED',remaining=[];
 if(route.route==='AUTHORITY_BLOCKED'){
   status='BLOCKED_AUTHORITY';remaining=['Original authorized branch requires real course-use authority; no replacement generated.'];
 }else if(legacy[caseId]){
   status='ISOLATED_SOURCE_BUNDLE_NOT_EXECUTED';remaining=['Existing legacy suites retain their own fixtures and transactions; not a production runner or exact new per-run budget.'];
 }else{
  if(!['S01','S02','L05'].includes(caseId)){
   const actors=['admin','studentA','studentB','teacher','creator','superAdmin','inactiveAdmin','lostRole'];
   command('synthetic-identities','fixture-owner',q('insert into auth.users(id,email) select x.id,x.email from jsonb_to_recordset($1::jsonb) as x(id uuid,email text)',
     [actors.map(a=>({id:id(a),email:'epic7-'+id(a)+'@example.invalid'}))],{kind:'rows',count:8}));
   for(const actor of actors){add('auth.users',[id(actor)]);add('public.profiles',[id(actor)]);add('public.user_roles',[id(actor),'student']);}
   const roles=[['admin','admin'],['teacher','teacher'],['superAdmin','super_admin'],['inactiveAdmin','admin']];
   command('synthetic-roles','fixture-owner',q('insert into public.user_roles(user_id,role) select x.user_id,x.role::public.app_role from jsonb_to_recordset($1::jsonb) as x(user_id uuid,role text)',
     [roles.map(([a,role])=>({user_id:id(a),role}))],{kind:'rows',count:4}));
   for(const [a,r] of roles)add('public.user_roles',[id(a),r]);
   mark('identity-peak-before-role-removal');
   command('inactive-actor','fixture-owner',q("update public.profiles set account_status='disabled' where user_id=$1::uuid",[id('inactiveAdmin')],{kind:'rows',count:1}));
   // Trigger-created student grants are removed only from disposable synthetic role-negative identities.
   const nonStudents=['admin','teacher','creator','lostRole'];
   command('synthetic-non-students','fixture-owner',q("delete from public.user_roles where user_id=any($1::uuid[]) and role='student'",[nonStudents.map(id)],{kind:'rows',count:4}));
   for(const a of nonStudents)inventory['public.user_roles'].delete(JSON.stringify([id(a),'student']));
   mark('identity-trigger-effects');
  }
  if(!['S01','S02','L05'].includes(caseId)){
   const stage=['H01'].includes(caseId)?'empty':['C01','C02','C03'].includes(caseId)?'structure':
     ['S03','S04','V01','V02','P01','P02','P03'].includes(caseId)?'frozen':'full';
   v=create('a',stage);mark('fixture-ready');
  }
  const deny=['42501','learning:course_use_denied'];
  const invalid=['P0001','learning:invalid_content'];
  switch(caseId){
   case 'S01':
    for(const t of Object.keys(tableKeys).filter(t=>!['auth.users','public.profiles','public.user_roles','public.audit_logs'].includes(t)))
     assertSQL('rls-'+t,'select relrowsecurity as value from pg_class where oid=$1::regclass',[t],true);
    for(const fn of functionContracts()){
     assertSQL('function-'+fn.signature,"select jsonb_build_object('owner',pg_get_userbyid(proowner),'config',proconfig,'definer',prosecdef) as value from pg_proc where oid=$1::regprocedure",[fn.signature],{owner:'postgres',config:['search_path=""'],definer:fn.securityDefiner});
     for(const role of fn.signature.startsWith('private.')?['anon','authenticated','service_role']:['anon','service_role'])
      assertSQL('function-deny-'+fn.signature+'-'+role,'select has_function_privilege($1,$2,$3) as value',[role,fn.signature,'EXECUTE'],false);
    }
    assertSQL('function-inventory',"select count(*)::int as value from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname like 'learning_%'",[],functionContracts().length);break;
   case 'S02':
    for(const t of Object.keys(tableKeys).filter(t=>t.startsWith('public.learning_')||t.startsWith('public.curriculum_')||t==='public.system_courses'||t==='public.content_contributors'))
     for(const role of ['anon','authenticated','service_role'])
      assertSQL('privilege-'+t+'-'+role,'select has_table_privilege($1,$2,$3) as value',[role,t,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'],false);
    for(const t of Object.keys(tableKeys).filter(t=>t.startsWith('public.learning_')||t.startsWith('public.curriculum_')||t==='public.system_courses'||t==='public.content_contributors')){
     const column=tableKeys[t][0];
     for(const role of ['anon','authenticated','service_role'])for(const text of ['select 1 from '+t+' limit 0','insert into '+t+' default values','update '+t+' set '+column+'='+column+' where false','delete from '+t+' where false'])
      command('raw-deny-'+role+'-'+t,role,q(text,[],{kind:'error',code:'42501',message:null}));
    }
    for(const fn of functionContracts().filter(fn=>fn.signature.startsWith('private.')&&!fn.trigger)){
     const sql='select '+fn.signature.replace(/\((.*)\)/,(_,args)=>'('+ (args?args.split(',').map(t=>'null::'+t).join(','):'') +')');
     for(const role of ['anon','authenticated','service_role'])command('private-deny-'+role+'-'+fn.signature,role,q(sql,[],{kind:'error',code:'42501',message:null}));
    }break;
   case 'S03':
    for(const actor of ['teacher','creator','studentA','inactiveAdmin','lostRole'])
     rpc('inspection-denied-'+actor,'learning_inspect_version',[v],['uuid'],null,actor,['42501','learning:not_authorized']);
    rpc('super-inspection','learning_inspect_version',[v],['uuid'],undefined,'superAdmin');
    steps.at(-1).query.expect={kind:'rows',count:1};break;
   case 'S04':
    command('inspection-privacy','admin',q('select public.learning_inspect_version($1::uuid) as value',[v],{kind:'dto',forbidden:['provider_ref','content','auth_user_id','subject_id','token']}));break;
   case 'H01':putStructure('a',v);create('b','structure');break;
   case 'H02':{
    create('b','structure');const s=structure('a');s.nodes[0].module_id=id('b-module0');
    mutation('cross-parent','structure',v,2,s,['P0001','learning:invalid_structure']);break;}
   case 'H03':{
    const s=structure('a');[s.nodes[0].position,s.nodes[1].position]=[s.nodes[1].position,s.nodes[0].position];
    putStructure('a',v,2,s,'reorder');s.nodes[1].position=s.nodes[0].position;
    mutation('duplicate-position','structure',v,3,s,['P0001','learning:invalid_structure']);s.nodes[0].position=0;mutation('nonpositive-position','structure',v,3,s,['P0001','learning:invalid_structure']);break;}
   case 'H04':
    rpc('draft-retry','learning_create_draft',[id('a-map'),v],['uuid','uuid'],v);
    rpc('draft-conflict','learning_create_draft',[id('a-map'),id('extra-version')],['uuid','uuid'],null,'admin',['P0001','learning:draft_conflict']);
    rpc('draft-actor-conflict','learning_create_draft',[id('a-map'),v],['uuid','uuid'],null,'superAdmin',['P0001','learning:idempotency_conflict']);break;
   case 'H05':
    mutation('content-retry','content',v,1,content('a'),null,'content-a');
    // Retry returns original revision, does not change rows/audit/revision.
    steps.at(-1).query.expect.value=2;
    mutation('payload-conflict','content',v,1,{},['P0001','learning:idempotency_conflict'],'content-a');
    mutation('stale-revision','content',v,0,{},['P0001','learning:revision_conflict']);break;
   case 'C01':
    assertSQL('no-resources','select count(*)::int as value from public.learning_node_resources where publication_id=$1::uuid',[v],0);break;
   case 'C02':
    putContent('a',v,1,{objectives:content('a').objectives});mutation('incomplete','freeze',v,2,undefined,['P0001','learning:incomplete_curriculum']);break;
   case 'C03':{
    const c=content('a');c.objectives=[];c.mappings=[];putContent('a',v,1,c);
    mutation('incomplete','freeze',v,2,undefined,['P0001','learning:incomplete_curriculum']);break;}
   case 'C04':mutation('freeze-text','freeze',v,2);break;
   case 'C05':{
    const c={links:[{id:id('extra-link'),node_id:id('a-node0'),resource_revision_id:id('a-resource-version1'),position:2,purpose:'apply'}]};
    putContent('a',v,2,c,'extra-link');create('b','full');
    mutation('foreign-resource','content',v,3,{links:[{...c.links[0],resource_revision_id:id('b-resource-version0')}]},invalid);break;}
   case 'C06':
    create('b','full');mutation('skill-rewrite','content',v,2,{skills:[{...content('a').skills[0],definition:'rewritten'}]},['P0001','learning:immutable_skill']);break;
   case 'C07':
    rpc('creator-not-admin','learning_inspect_version',[v],['uuid'],null,'creator',['42501','learning:not_authorized']);
    assertSQL('credits-retained','select count(*)::int as value from public.learning_author_credits where publication_id=$1::uuid',[v],2);break;
   case 'C08':
    putContent('a',v,2,{capabilities:['submission','verification','assessment'].map(code=>({id:id('cap-'+code),node_id:id('a-node0'),code,description:'Metadata only'}))},'all-capability-codes');
    for(const field of ['quota','result','reviewer'])mutation('invalid-'+field,'content',v,3,{capabilities:[{...content('a').capabilities[0],[field]:1}]},['P0001','learning:invalid_fields']);
    break;
   case 'G01':{
    const edge={dependent_node_id:id('a-node1'),prerequisite_node_id:id('a-node0')};
    putContent('a',v,2,{prerequisites:[edge]},'edge');
    mutation('reverse-cycle','content',v,3,{prerequisites:[{dependent_node_id:edge.prerequisite_node_id,prerequisite_node_id:edge.dependent_node_id}]},['P0001','learning:prerequisite_cycle']);break;}
   case 'G02':{
    mutation('complete-freeze','freeze',v,2);
    const b=create('b','empty'),shape=structure('b');
    putStructure('b',b,0,{levels:shape.levels,modules:[],nodes:[]},'empty-stage');
    mutation('empty-stage-freeze','freeze',b,1,undefined,['P0001','learning:incomplete_curriculum']);
    putStructure('b',b,1,{levels:[],modules:shape.modules,nodes:[]},'empty-module');
    mutation('empty-module-freeze','freeze',b,2,undefined,['P0001','learning:incomplete_curriculum']);break;
   }
   case 'G03':
    assertSQL('freeze-graph-trigger',"select count(*)::int as value from pg_trigger where tgrelid='public.curriculum_publications'::regclass and tgname='learning_freeze_graph' and tgenabled='O'",[],1);
    mutation('normal-freeze','freeze',v,2);break;
   case 'V01':
    mutation('freeze-retry','freeze',v,2,undefined,null,'freeze-a');
    steps.at(-1).query.expect.value=3;
    mutation('frozen-edit','content',v,3,{},['P0001','learning:immutable_version']);break;
   case 'V02':{
    const second=draft('a','-second');const changed=structure('a');changed.nodes.forEach(n=>n.title+=' V2');
    putStructure('a',second,0,changed,'structure-second');
    const revised=content('a');revised.resources.forEach((r,i)=>r.revision_id=id('v2-resource-'+i));
    revised.links.forEach((r,i)=>r.resource_revision_id=id('v2-resource-'+i));
    revised.credits.forEach(r=>r.resource_revision_id=id('v2-resource-0'));
    putContent('a',second,1,revised,'content-second');mutation('freeze-second','freeze',second,2);
    assertSQL('old-revision','select revision as value from public.curriculum_publications where id=$1::uuid',[v],3);break;}
   case 'P01':case 'P02':case 'P03':{
    const actors=caseId==='P03'?['teacher','creator','admin','lostRole','inactiveAdmin']:['studentA','studentB'];
    for(const actor of actors){
     const error=caseId==='P03'?['42501','learning:student_required']:deny;
     rpc('get-denied-'+actor,'learning_get_own_activity',[v,id('a-node0')],['uuid','uuid'],null,actor,error);
     rpc('set-denied-'+actor,'learning_set_activity',[v,id('a-node0'),0,id('activity-'+actor),caseId==='P02'?{subject_id:id('studentB'),verified:true}:{opened:true}],
       ['uuid','uuid','integer','uuid','jsonb'],null,actor,error);
    }
    remaining.push('Early denial does not prove downstream positive/field validation.');
    break;}
   case 'R01':case 'R02':case 'R03':
    status='COMPILED_RACE_SCHEDULE_NOT_EXECUTED';
    remaining.push('Two independent PostgreSQL sessions and lock barrier required; no serial substitute or production commit.');
    break;
   case 'L05':status='OBSERVER_ONLY_NOT_EXECUTED';break;
   default:fail('CASE_COMPILER_MISSING');
  }
  mark('case-complete');
 }
 const dependencies=new Map();
 function collectLegacy(name,stack=[]){
  if(!/^[a-z0-9_.-]+\.sql$/.test(name)||stack.includes(name))fail('INVALID_LEGACY_INCLUDE');
  if(dependencies.has(name))return;
  const path='supabase/tests/database/'+name,bytes=readFileSync(new URL(path,root));
  dependencies.set(name,{path,sha256:hash(bytes),mode:'ISOLATED_ONLY',executed:false});
  for(const m of bytes.toString('utf8').matchAll(/^\\ir\s+([a-z0-9_.-]+\.sql)\s*$/gm))collectLegacy(m[1],[...stack,name]);
 }
 for(const name of legacy[caseId]??[])collectLegacy(name);
 const sources=[...dependencies.values()];
 // Deterministic held-lock schedules have one accepted mutation; retry/loser adds no receipt.
 if(['R01','R02','R03'].includes(caseId)){
  const v=id('a-version'),key=id(caseId==='R01'?'race-a':'race-freeze');
  add('public.learning_mutation_receipts',[v,id('admin'),key]);
  audit('learning.'+(caseId==='R01'?'content':'freeze'),v,key);
  if(caseId==='R01')add('public.learning_node_prerequisites',[v,id('a-node1'),id('a-node0')]);
  mark('race-final-expected');
 }
 const rows=Object.fromEntries(Object.entries(inventory).map(([t,keys])=>[t,{keys:[...keys.values()],count:keys.size,ceiling:BUDGETS[t],expectedRetained:caseId.startsWith('R')?keys.size:0}]));
 for(const [t,r] of Object.entries(rows))if(r.count>r.ceiling)fail('BUDGET_EXCEEDED_'+t);
 const races=caseId==='R01'?{barrier:'FIRST_SESSION_VERSION_LOCK_HELD',first:{rpc:'learning_put_content',args:[v,2,id('race-a'),{prerequisites:[{dependent_node_id:id('a-node1'),prerequisite_node_id:id('a-node0')}]}]},
   second:{rpc:'learning_put_content',args:[v,3,id('race-b'),{prerequisites:[{dependent_node_id:id('a-node0'),prerequisite_node_id:id('a-node1')}]}]},expected:['SUCCESS','learning:prerequisite_cycle']}:
   ['R02','R03'].includes(caseId)?{barrier:'FIRST_SESSION_VERSION_LOCK_HELD',first:{rpc:'learning_freeze_version',args:[v,2,id('race-freeze')]},
   second:caseId==='R02'?{rpc:'learning_freeze_version',args:[v,2,id('race-freeze')]}:{rpc:'learning_put_structure',args:[v,2,id('race-edit'),structure('a')]},
   expected:caseId==='R02'?['SUCCESS','SAME_REVISION']:['SUCCESS','learning:immutable_version']}:null;
 const plan={format:1,caseId,runId,identity,route,status,remaining,actors:Object.fromEntries([...ids].filter(([k])=>['admin','studentA','studentB','teacher','creator','superAdmin','inactiveAdmin','lostRole'].includes(k))),
  steps,checkpoints,rows,sources,races,retention:'ROLLBACK_ONLY_PLAN; RACE_ISOLATED_COMMIT_PROPOSAL_NOT_APPROVED',
  target:'NO_DATABASE_TRANSPORT',productionAllowed:false,fullCaseProven:false};
 plan.planHash=hash(plan);immutable(plan);trusted.add(plan);return plan;
}
