import {CASES} from '../epic7-owner-policy.mjs';
import {requirePlan} from './compile.mjs';
import {tableKeys,immutable,hash,fail} from './schema.mjs';

// A budget is a compiled expectation, not an observed row count.
export function auditBudget(plan){
 requirePlan(plan);
 const unknown=plan.sources.length>0,blocked=plan.status==='BLOCKED_AUTHORITY';
 const tables={};let previous=0;
 for(const c of plan.checkpoints){
  if(!Number.isSafeInteger(c.afterStep)||c.afterStep<previous||c.afterStep>plan.steps.length)fail('BUDGET_CHECKPOINT');
  previous=c.afterStep;
  if(JSON.stringify(Object.keys(c.counts).sort())!==JSON.stringify(Object.keys(tableKeys).sort()))fail('BUDGET_TABLES');
 }
 for(const [table,r] of Object.entries(plan.rows)){
  if(r.count!==r.keys.length||new Set(r.keys.map(k=>JSON.stringify(k))).size!==r.count)fail('BUDGET_KEYS');
  const checkpoints=plan.checkpoints.map(c=>c.counts[table]);
  if(checkpoints.some(n=>!Number.isSafeInteger(n)||n<0))fail('BUDGET_COUNT');
  const peak=Math.max(r.count,...checkpoints);
  if(peak>r.ceiling)fail('BUDGET_PEAK_EXCEEDED');
  tables[table]={expectedFinal:unknown?null:r.count,expectedPeak:unknown?null:peak,
   ceiling:r.ceiling,expectedAfterRollback:unknown?null:0,
   isolatedCommitProposal:unknown?null:plan.races?r.expectedRetained:0,
   keys:unknown?null:r.keys,reason:unknown?'LEGACY_EFFECTS_NOT_COMPILED':blocked?'NO_AUTHORITY_NO_FIXTURE':'COMPILED_NOT_OBSERVED'};
 }
 const knownTotal=field=>unknown?null:Object.values(tables).reduce((n,t)=>n+t[field],0);
 return immutable({caseId:plan.caseId,runId:plan.runId,planHash:plan.planHash,tables,
  totals:{finalRows:knownTotal('expectedFinal'),sumOfTablePeaks:knownTotal('expectedPeak'),
   retainedAfterRollback:knownTotal('expectedAfterRollback'),isolatedCommitProposal:knownTotal('isolatedCommitProposal')},
  peakMeaning:'Sum of individual table maxima; not a claim that all maxima occur simultaneously.',
  budgetComplete:!unknown,budgetVerifiedByDatabase:false,fixtureCreationAllowed:false,
  generatedAuditIds:'Observed from PostgreSQL; manifest tuples are not audit primary keys.',
  stopOn:'Unknown budget, key collision, unexpected count, unknown commit outcome or failed independent observation.',
  hash:hash({planHash:plan.planHash,tables})});
}
export function localReadiness(plans){
 if(!Array.isArray(plans)||plans.length!==37)fail('READINESS_CASE_COUNT');
 plans.forEach(requirePlan);
 if(JSON.stringify(plans.map(p=>p.caseId).sort())!==JSON.stringify([...CASES].sort()))fail('READINESS_CASE_IDS');
 const cases=plans.map(p=>({caseId:p.caseId,status:p.status,budget:auditBudget(p),remaining:p.remaining}));
 // No caller-supplied PASS or approval flag can upgrade unexecuted programs.
 return immutable({status:'BLOCKER',remoteExecutionReady:false,remotePreflightExecutionAllowed:false,
  reviewPreparationAllowed:true,production:{connections:0,sql:0,writes:0},cases,
  engineering:[
   'Pinned local PostgreSQL transport, cancellation, transaction state and actual rollback sentinel not verified.',
   'Serial domain SQL and actual trigger effects not executed against PostgreSQL.',
   'R01-R03 real independent-session lock barrier and unknown commit outcome not executed.',
   'L01-L04 per-run legacy fixture effects and precise budgets not compiled or measured.',
   'Observer SQL, role visibility, complete inventory and independent snapshots not executed against PostgreSQL.',
   'Formal transport and attestation remain absent; no caller SHA or decoded observation is formal proof.'
  ],
  authorityGaps:plans.filter(p=>p.status==='BLOCKED_AUTHORITY').map(p=>p.caseId),
  legacyBudgetUnknown:plans.filter(p=>p.sources.length).map(p=>p.caseId)});
}
