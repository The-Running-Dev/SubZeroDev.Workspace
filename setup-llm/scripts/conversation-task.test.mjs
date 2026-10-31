import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { run } from './conversation-task.mjs';
import { spawnSync } from 'node:child_process';

test('literal arguments, private output and failure redaction', () => {
 const base=mkdtempSync(join(tmpdir(),'conversation task ü & $() '));
 try {
  writeFileSync(join(base,'INDEX.md'),'# Synthetic\n<!-- notes -->\n');
  const kit=join(base,'kit'); mkdirSync(join(kit,'tools'),{recursive:true});
  writeFileSync(join(kit,'tools/conversation.ts'), `console.log(JSON.stringify({State:'Forked',Revision:1,Packet:'SECRET_BODY',args:process.argv.slice(2)}));`);
  const request=join(base,'request & ü.json');writeFileSync(request,JSON.stringify({action:'fork'}));
  const args=['--operation','fork','--archive-root',base,'--request-file',request];
  assert.equal(run(['--operation','fork','--archive-root','','--request-file',request]).exitCode,1);
  const r=run(args,{...process.env,AGENTKIT_HOME:kit}); assert.equal(r.exitCode,0);
  assert.ok(!JSON.stringify(r.report).includes('SECRET_BODY'));
  const saved=JSON.parse(readFileSync(fileURLToPath(r.report.Result)));
  assert.deepEqual(saved.args,['--archive-root',base,'--request-file',request]);
  assert.equal(saved.Packet,'SECRET_BODY');
  writeFileSync(join(kit,'tools/conversation.ts'),`console.error('SECRET_BODY');process.exit(1);`);
  assert.ok(!JSON.stringify(run(args,{...process.env,AGENTKIT_HOME:kit})).includes('SECRET_BODY'));
  writeFileSync(request,JSON.stringify({action:'attach'}));assert.equal(run(args).exitCode,1);
 } finally {rmSync(base,{recursive:true,force:true});}
});

test('store preserves an accepted replay without describing it as a candidate', () => {
 const base=mkdtempSync(join(tmpdir(),'conversation store replay ü & '));
 try {
  writeFileSync(join(base,'INDEX.md'),'# Synthetic\n<!-- notes -->\n');
  const kit=join(base,'kit'); mkdirSync(join(kit,'tools'),{recursive:true});
  const store=join(base,'synthetic-store.json');
  // Synthetic adapter only, adapted from #61's accepted-replay regression.
  // Storage keeps the original receipt while replay reads the current record.
  // Acceptance is deliberately a separate fixture edit below, never a store action.
  writeFileSync(join(kit,'tools/conversation-memory.ts'), `
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
const args=process.argv.slice(2);
const request=JSON.parse(readFileSync(args[args.indexOf('--request-file')+1],'utf8'));
const file=process.env.SYNTHETIC_STORE;
const identity=JSON.stringify([request.branchId,request.reviewId,request.selected]);
let db, state;
if (existsSync(file)) {
 db=JSON.parse(readFileSync(file,'utf8'));
 if (db.receipt.operationId!==identity) throw Error('Unexpected operation identity');
 state='Replayed';
} else {
 const memory={id:'PRIVATE_MEMORY_ID',status:'candidate',verification:'unverified',revision:1,content:'PRIVATE_MEMORY_BODY'};
 db={records:[memory],receipt:{operationId:identity,memory:{...memory},history:'persisted'}};
 writeFileSync(file,JSON.stringify(db));
 state='Stored';
}
console.log(JSON.stringify({State:'Stored',Results:{decision:{State:state,Memory:db.records[0],Receipt:db.receipt}},args}));
`);
  const request=join(base,'store.json');
  writeFileSync(request,JSON.stringify({schemaVersion:1,action:'store',branchId:'synthetic',reviewId:'review-one',selected:['decision']}));
  const requestBytes=readFileSync(request,'utf8');
  const wrapper=fileURLToPath(new URL('./conversation-task.mjs',import.meta.url));
  const invoke=()=>{
   const child=spawnSync(process.execPath,[wrapper,'--operation','store','--archive-root',base,'--request-file',request],{
    env:{...process.env,AGENTKIT_HOME:kit,SYNTHETIC_STORE:store},shell:false,encoding:'utf8',
   });
   assert.equal(child.status,0,child.stdout+child.stderr);
   const report=JSON.parse(child.stdout);
   assert.equal(report.State,'Stored');
   for (const secret of ['PRIVATE_MEMORY_ID','PRIVATE_MEMORY_BODY','review-one','Replayed']) assert.ok(!(child.stdout+child.stderr).includes(secret));
   return {stdout:child.stdout,report,value:JSON.parse(readFileSync(fileURLToPath(report.Result),'utf8'))};
  };
  const initial=invoke();
  assert.equal(initial.value.Results.decision.State,'Stored');
  assert.equal(initial.value.Results.decision.Memory.status,'candidate');
  assert.equal(initial.value.Results.decision.Memory.verification,'unverified');
  assert.deepEqual(initial.value.args,['--archive-root',base,'--request-file',request,'--project',base]);
  const receipt=initial.value.Results.decision.Receipt;
  const candidateRetry=invoke();
  assert.equal(candidateRetry.value.Results.decision.State,'Replayed');
  assert.equal(candidateRetry.value.Results.decision.Memory.status,'candidate');
  assert.deepEqual(candidateRetry.value.Results.decision.Receipt,receipt);
  // Explicit acceptance between the write and identical retry, as in #61.
  const db=JSON.parse(readFileSync(store,'utf8'));
  db.records[0].status='accepted'; db.records[0].revision=2;
  writeFileSync(store,JSON.stringify(db));
  const acceptedStore=readFileSync(store,'utf8');
  const replay=invoke();
  assert.equal(replay.value.Results.decision.State,'Replayed');
  assert.equal(replay.value.Results.decision.Memory.status,'accepted');
  assert.equal(replay.value.Results.decision.Memory.revision,2);
  assert.deepEqual(replay.value.Results.decision.Receipt,receipt);
  assert.match(replay.stdout,/Storage does not accept memories/);
  assert.doesNotMatch(replay.stdout,/candidate/i);
  assert.equal(readFileSync(store,'utf8'),acceptedStore); // no new record, demotion or receipt rewrite
  assert.equal(readFileSync(request,'utf8'),requestBytes);
  assert.equal(invoke().report.Result,replay.report.Result); // identical replay transport is stable
  assert.equal(JSON.parse(readFileSync(fileURLToPath(initial.report.Result),'utf8')).Results.decision.Memory.status,'candidate');
 } finally {rmSync(base,{recursive:true,force:true});}
});

test('real AgentKit fork, attach, return, review and memory-off entrypoints', {skip:!process.env.AGENTKIT_TEST_HOME},()=>{
 const base=mkdtempSync(join(tmpdir(),'editor synthetic ü & '));
 try {
  writeFileSync(join(base,'INDEX.md'),'# Synthetic\n<!-- notes -->\n');
  const source=join(base,'source.txt');writeFileSync(source,'Use plain text.');
  const statement={role:'user',kind:'exact',text:'Use plain text.',refs:[{sourceId:'source',startByte:0,endByte:15}]};
  const env={...process.env,AGENTKIT_HOME:process.env.AGENTKIT_TEST_HOME,AGENTKIT_MEMORYKIT_CONFIG:join(base,'absent.json')};
  const invoke=(operation,request)=>{const path=join(base,operation+'.json');writeFileSync(path,JSON.stringify(request));return run(['--operation',operation,'--archive-root',base,'--request-file',path],env);};
  const fork={schemaVersion:1,action:'fork',branchId:'synthetic',operationId:'fork-one',date:'2026-10-28',parent:{uri:'https://example.invalid/parent',bookmark:'Synthetic',question:'Format?'},sources:[{id:'source',file:source,coverage:'Synthetic excerpt',missing:[],uncertainty:[]}],handoff:[statement]};
  assert.equal(invoke('fork',fork).report.State,'Forked');
  assert.equal(invoke('fork',fork).report.Revision,1);
  assert.equal(invoke('attach',{schemaVersion:1,action:'attach',branchId:'synthetic',operationId:'attach-one',expectedRevision:1,sources:[],handoff:[statement]}).report.Revision,2);
  const returned=invoke('return',{schemaVersion:1,action:'return',branchId:'synthetic',expectedRevision:2,outcome:[statement]});assert.equal(returned.report.State,'Returned');
  assert.match(readFileSync(fileURLToPath(returned.report.Result),'utf8'),/example.invalid\/parent/);
  assert.equal(invoke('review',{schemaVersion:1,action:'propose',branchId:'synthetic',reviewId:'review-one',expectedRevision:2,proposals:[{id:'decision',kind:'decision',statementIndex:0,statement:'source'}]}).report.State,'Proposed');
  const off=invoke('store',{schemaVersion:1,action:'store',branchId:'synthetic',reviewId:'review-one',selected:['decision']});assert.equal(off.exitCode,2);assert.equal(off.report.State,'NotConfigured');
  if (process.env.MEMORYKIT_CLI) {
   assert.equal(spawnSync('git',['init',base]).status,0);
   assert.equal(spawnSync('git',['-C',base,'remote','add','origin','https://example.invalid/synthetic/notes.git']).status,0);
   const store=join(base,'synthetic-store');
   assert.equal(spawnSync(process.execPath,[process.env.MEMORYKIT_CLI,'init',store],{encoding:'utf8'}).status,0);
   writeFileSync(env.AGENTKIT_MEMORYKIT_CONFIG,JSON.stringify({cli:process.env.MEMORYKIT_CLI,store,capture:false,context:false}));
   const stored=invoke('store',{schemaVersion:1,action:'store',branchId:'synthetic',reviewId:'review-one',selected:['decision']});
   assert.equal(stored.exitCode,0,readFileSync(fileURLToPath(stored.report.Result),'utf8'));assert.equal(stored.report.State,'Stored');
   const result=JSON.parse(readFileSync(fileURLToPath(stored.report.Result)));
   assert.equal(result.Results.decision.Memory.status,'candidate');
   assert.equal(result.Results.decision.Memory.verification,'unverified');
  }
 } finally {rmSync(base,{recursive:true,force:true});}
});


