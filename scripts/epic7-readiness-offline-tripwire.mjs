// Test-only process tripwire: any connection/process/env-file use aborts validation.
import net from 'node:net';
import tls from 'node:tls';
import http from 'node:http';
import https from 'node:https';
import dns from 'node:dns';
import child from 'node:child_process';
import fs from 'node:fs';
import {syncBuiltinESMExports} from 'node:module';
const deny=()=>{throw Error('OFFLINE SIDE EFFECT DETECTED');};
globalThis.fetch=deny;
for(const api of [net,tls])for(const k of ['connect','createConnection'])if(k in api)api[k]=deny;
net.Socket.prototype.connect=deny;
for(const api of [http,https]){api.request=deny;api.get=deny;}
dns.lookup=deny;dns.resolve=deny;
for(const k of ['spawn','spawnSync','exec','execSync','execFile','execFileSync','fork'])child[k]=deny;
const read=fs.readFileSync;
fs.readFileSync=(p,...args)=>{if(/(?:^|[\\/])\.env(?:\.|$)/.test(String(p)))deny();return read(p,...args);};
syncBuiltinESMExports();
