// Offline planning only. No transports, credentials, approval tokens or execution entry point.
export const CASES = Object.freeze(Object.entries({ S:4,H:5,C:8,G:3,V:2,P:6,R:4,L:5 })
  .flatMap(([prefix,count]) => Array.from({length:count},(_,i) => prefix+String(i+1).padStart(2,'0'))));
export function classifyCase(id) {
  if (!CASES.includes(id)) throw new Error('UNKNOWN_CASE');
  const blocked = ['P04','P05','P06','R04'].includes(id);
  const isolated = id.startsWith('R');
  return Object.freeze({id, route:blocked?'AUTHORITY_BLOCKED':isolated?'ISOLATED_ONLY':'PRODUCTION_PROPOSAL',
    committed:isolated, remoteStatus:'REMOTE NOT RUN', approvedDeferral:false,
    executionAllowed:false, closure:'PROPOSED / PENDING APPROVAL'});
}
export const SERVICES = Object.freeze(['database','auth','storage','application','traffic',
  'secrets','connections','extensions','migrationHistory','reopeningWrites','realtimeAndFunctions']);
const keys = ['scope','controlledBy','encrypted','accessRestricted','custodianRecorded','retentionRecorded',
  'restoreVerified','consistent','pointUTC','assessmentUTC','services'];
const exact = (x, expected) => x && typeof x==='object' && !Array.isArray(x)
  && Object.keys(x).sort().join('|') === [...expected].sort().join('|');
const utc = x => typeof x==='string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(x)
  && Number.isFinite(Date.parse(x)) && new Date(x).toISOString()===x;
// Caller metadata is never trusted production evidence. Even a clean simulation grants no permission.
export function assessRecovery(input) {
  const reasons = [];
  if (!exact(input,keys) || !exact(input?.services,SERVICES)) reasons.push('INVALID_METADATA');
  else {
    if(input.scope!=='WHOLE_SITE') reasons.push('DB_DRILL_IS_NOT_SITE_RECOVERY');
    if(input.controlledBy!=='THE_ONE') reasons.push('WRONG_STORAGE_CONTROL');
    for(const key of ['encrypted','accessRestricted','custodianRecorded','retentionRecorded','restoreVerified','consistent'])
      if(input[key]!==true) reasons.push(key.toUpperCase()+'_UNPROVEN');
    if(!utc(input.pointUTC)||!utc(input.assessmentUTC)) reasons.push('INVALID_TIME');
    else {
      const age=Date.parse(input.assessmentUTC)-Date.parse(input.pointUTC);
      if(age<0 || age>3600000) reasons.push('RECOVERY_POINT_OUTSIDE_ONE_HOUR');
    }
    for(const key of SERVICES)
      if(!['VERIFIED','VERIFIED_NOT_USED'].includes(input.services[key])
        || (input.services[key]==='VERIFIED_NOT_USED' && !['storage','realtimeAndFunctions'].includes(key)))
        reasons.push('SERVICE_'+key.toUpperCase()+'_UNPROVEN');
  }
  return Object.freeze({mode:'OFFLINE_PLANNING',status:reasons.length?'STOP':'SIMULATED_REQUIREMENTS_MET',
    reasons:Object.freeze(reasons),maxLossSeconds:3600,executionAllowed:false,brPass:false,
    continuousRecoveryProven:false});
}
