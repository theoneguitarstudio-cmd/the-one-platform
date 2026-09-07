import {requirePlan} from './compile.mjs';
import {hash,tableKeys} from './schema.mjs';
const transports=new WeakSet();
export function requireTestTransport(t){if(!transports.has(t))throw Error('WRONG_LOCAL_TARGET');}
const emptySnapshot=(p,connectionId=2)=>({runId:p.runId,connectionId,at:new Date().toISOString(),writerClosed:true,
 tables:Object.fromEntries(Object.keys(tableKeys).map(t=>[t,[]])),catalogHash:hash('catalog'),sequenceHash:hash('sequence'),
 allTables:{'public.system_courses':{count:'0',fingerprint:hash('empty')},'auth.users':{count:'0',fingerprint:hash('empty')}}});
export function createTestDouble(p,fault={}){
 requirePlan(p);
 const allowed=['begin','sentinel','role','timeout','queryAt','missingError','domain','sqlstate','rows','dto','budget','cancel','rollback','close','target','connect','connectTimeout','observer','reusedReader','missingTable','residue','residueSentinel'];
 for(const [key,value] of Object.entries(fault))if(!allowed.includes(key)||(key==='queryAt'? !Number.isInteger(value)||value<1||value>10000 : typeof value!=='boolean'))throw Error('INVALID_FAULT');
 fault=Object.freeze({...fault});
 const calls=[];let observes=0;let queryIndex=0;
 const writer={identity:{environment:'ISOLATED_TEST_DOUBLE',runId:p.runId,backendId:1},transactionStatus:'I',closed:false,actor:null,
  async begin(){calls.push('begin');this.transactionStatus='T';if(fault.begin)throw Error('driver credential must not leak');},
  async configure(options){if(!(options.lockTimeoutMs<options.statementTimeoutMs))throw Error('INVALID_TIMEOUT');calls.push('configure');},
  async sentinel(){return fault.sentinel?{before:0,inside:1,outside:1}:{before:0,inside:1,outside:0};},
  async asActor(actor){calls.push('role');this.actor=fault.role?'other':actor;},
  async savepoint(){calls.push('savepoint');},
  async rollbackSavepoint(){calls.push('rollback-savepoint');this.transactionStatus='T';},
  async releaseSavepoint(){calls.push('release');},
  async query(query,signal){
   calls.push('query');queryIndex++;
   if(fault.timeout){await new Promise(r=>setTimeout(r,35));if(signal.aborted){calls.push('late-cancelled');throw Error('aborted');}}
   if(fault.queryAt===queryIndex)throw Error('password=DO_NOT_LEAK');
   if(query.expect.kind==='error'){
    this.transactionStatus='E';
    if(fault.missingError)return {rowCount:1,rows:[{value:1}]};
    const error=new Error(fault.domain?'wrong domain':query.expect.message);error.code=fault.sqlstate?'XX000':query.expect.code;throw error;
   }
   if(fault.rows)return {rowCount:0,rows:[]};
   const value=query.expect.kind==='dto'?(fault.dto?{provider_ref:'SECRET'}:{id:'synthetic',nodes:[]}):query.expect.value;
   return {rowCount:query.expect.kind==='rows'?query.expect.count:1,rows:[{value}]};
  },
  async scopeCounts(){const cp=p.checkpoints.find(c=>c.afterStep===queryIndex);const result={...cp.counts};if(fault.budget)result['public.audit_logs']++;return result;},
  async cancel(){calls.push('cancel');return !fault.cancel;},
  async rollback(){calls.push('rollback');if(fault.rollback)throw Error('rollback secret');this.transactionStatus='I';},
  async close(){calls.push('close');if(fault.close)throw Error('close secret');this.closed=true;this.transactionStatus='I';}
 };
 if(fault.target)writer.identity.environment='PRODUCTION';
 const transport={mode:'ISOLATED_TEST_DOUBLE',
  async open(){calls.push('open');if(fault.connect)throw Error('credential');if(fault.connectTimeout)await new Promise(r=>setTimeout(r,35));return writer;},
  async observe(plan,signal,closed){
   observes++;calls.push('observe');if(fault.observer)throw Error('observer secret');
   const snapshot=emptySnapshot(plan,observes+1);snapshot.writerClosed=closed;
   if(fault.reusedReader)snapshot.connectionId=1;
   if(fault.missingTable)delete snapshot.tables['auth.users'];
   if(fault.residue&&observes>1)snapshot.tables['public.system_courses']=[{key:[plan.runId],fingerprint:hash('extra')}];
   return snapshot;
  },
  async sentinelResidue(){return fault.residueSentinel?1:0;}
 };
 Object.freeze(writer.identity);
 for(const [key,value] of Object.entries(writer))if(typeof value==='function'||key==='identity')Object.defineProperty(writer,key,{writable:false,configurable:false});
 Object.seal(writer);Object.freeze(transport);transports.add(transport);
 return Object.freeze({transport,get calls(){return [...calls];},get writer(){return {closed:writer.closed};}});
}