import {mkdirSync,lstatSync,existsSync,writeFileSync,readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join,relative,sep} from 'node:path';
import {root,hash,fail} from './schema.mjs';
import {requirePlan} from './compile.mjs';
import {requireReport} from './session.mjs';
export function writeEvidence(plan,report){
 requirePlan(plan);requireReport(report);
 if(report.planHash!==plan.planHash||report.fixtureRunId!==plan.runId)fail('EVIDENCE_BINDING');
 const base=fileURLToPath(root), parts=['artifacts','remote-smoke','epic7-local-engineering',report.runId];
 let directory=base;
 for(const part of parts){
  directory=join(directory,part);
  if(existsSync(directory)){const stat=lstatSync(directory);if(stat.isSymbolicLink()||!stat.isDirectory())fail('EVIDENCE_LINK');}
  else mkdirSync(directory);
 }
 const files={'plan.json':plan,'result.json':report,'observer.json':report.observer};
 // No raw adapter errors, result rows, credentials, real .env, or database content.
 const hashes={};
 for(const [name,value] of Object.entries(files)){
  const bytes=JSON.stringify(value,null,2)+'\n';if(Buffer.byteLength(bytes)>4*1024*1024)fail('EVIDENCE_TOO_LARGE');
  const path=join(directory,name);writeFileSync(path,bytes,{flag:'wx',mode:0o600});hashes[name]=hash(readFileSync(path));
 }
 writeFileSync(join(directory,'hashes.json'),JSON.stringify(hashes,null,2)+'\n',{flag:'wx',mode:0o600});
 return relative(base,directory).split(sep).join('/');
}

export function writePlanBundle(plans){
 if(!Array.isArray(plans)||plans.length!==37)fail('CASE_BUNDLE_COUNT');
 plans.forEach(requirePlan);
 if(new Set(plans.map(p=>p.caseId)).size!==37)fail('CASE_BUNDLE_DUPLICATE');
 const bundleId=plans[0].runId,base=fileURLToPath(root);
 let dir=base;
 for(const part of ['artifacts','remote-smoke','epic7-local-engineering','compiled-'+bundleId]){
  dir=join(dir,part);if(existsSync(dir)){const stat=lstatSync(dir);if(stat.isSymbolicLink()||!stat.isDirectory())fail('EVIDENCE_LINK');}else mkdirSync(dir);
 }
 const files={};
 for(const p of plans){
  const bytes=JSON.stringify(p,null,2)+'\n';writeFileSync(join(dir,p.caseId+'.json'),bytes,{flag:'wx',mode:0o600});files[p.caseId+'.json']=hash(bytes);
 }
 const codeFiles=['schema.mjs','compile.mjs','observe.mjs','session.mjs','evidence.mjs','test-double.mjs','engineering.test.mjs'];
 const toolHashes=Object.fromEntries(codeFiles.map(n=>[n,hash(readFileSync(new URL('tools/epic7-local-engineering/'+n,root)))]));
 const summary={format:1,at:new Date().toISOString(),mode:'OFFLINE_COMPILE_ONLY',production:{connections:0,sql:0,writes:0},
  cases:plans.map(p=>({caseId:p.caseId,status:p.status,commands:p.steps.length,remaining:p.remaining,
   budget:p.sources.length?'LEGACY_RUNTIME_BUDGET_UNVERIFIED':'COMPILED_KEYS_AND_COUNTS_NOT_DB_PROOF',domainTestExecuted:false})),
  files,toolHashes,approval:false};
 writeFileSync(join(dir,'index.json'),JSON.stringify(summary,null,2)+'\n',{flag:'wx',mode:0o600});
 return relative(base,dir).split(sep).join('/');
}
