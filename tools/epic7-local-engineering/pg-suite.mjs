import {mkdirSync,readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {serial} from './pg-cases.mjs';
import {race} from './pg-races.mjs';
import {legacy} from './pg-legacy.mjs';
import {record} from './pg-local.mjs';
import {CASES} from '../epic7-owner-policy.mjs';
import {candidate} from './schema.mjs';
if(process.argv[2]!=='--all-synthetic'||process.argv.length!==4)throw Error('LOCAL_USAGE');
const file=process.argv[3],dir='artifacts/remote-smoke/epic7-pg-final-'+randomUUID(),start=new Date().toISOString();mkdirSync(dir,{recursive:true});console.log(dir);
const results=[];let stop=null;
try{for(const id of CASES){if(['R01','R02','R03'].includes(id))await race(file,id,dir);else if(['L01','L02','L03','L04'].includes(id))await legacy(file,id,dir);else await serial(file,id,dir);const r=JSON.parse(readFileSync(dir+'/'+id+'.json','utf8'));results.push({caseId:id,result:r.result});}}
catch(e){stop=e.message;process.exitCode=1;}
finally{record(dir,'summary',{candidate,toolBaseline:'2eac1b9e8d69d0e3628120121f9a4f7058457325',node:process.version,start,end:new Date().toISOString(),results,stop,notRun:CASES.filter(id=>!results.some(r=>r.caseId===id)),remote:'NOT RUN',production:{connections:0,writes:0}});console.log(JSON.stringify({dir,results,stop}));}
