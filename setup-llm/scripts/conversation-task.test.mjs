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


