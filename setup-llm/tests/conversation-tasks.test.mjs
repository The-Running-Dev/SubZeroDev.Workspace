import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { fixture } from './conversation-task-fixture.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const wrapper = join(root, 'setup-llm/scripts/Invoke-ConversationTask.mjs');
const tasks = JSON.parse(readFileSync(join(root, '.vscode/tasks.json'), 'utf8'));
const invoke = (args, env = {}, cwd = root) => spawnSync(process.execPath, [wrapper, ...args], {
  cwd, env: { ...process.env, ...env }, shell: false, encoding: 'utf8', maxBuffer: 1024 * 1024,
});
const put = (path, value) => { writeFileSync(path, JSON.stringify(value)); return path; };
const outputDir = (request, r) => join(dirname(request), /Private result: (\.conversation-result-[\w-]+)\/result.json/.exec(r.stdout)?.[1] ?? 'MISSING');
function selected(f, operation, request = f.requests[operation], extras = []) {
  return ['--operation', operation, '--archive-root', f.archive, '--request-file', request, ...extras];
}
function privacy(r, f) {
  const log = r.stdout + r.stderr;
  for (const secret of [f.base, f.archive, f.project, 'UNSELECTED_SYNTHETIC_BODY', 'SYNTHETIC_PRIVATE_BOOKMARK', 'Use portable handoffs.', 'The later result is available.']) {
    assert.ok(!log.includes(secret), `Task log disclosed ${secret}`);
  }
}

test('tasks are manual process entry points, with private explicit selections and preserved provisioning', () => {
  const conversation = tasks.tasks.filter(t => t.label.startsWith('Conversation:'));
  assert.equal(conversation.length, 6);
  assert.deepEqual(conversation.map(t => t.args[t.args.indexOf('--operation') + 1]), ['fork', 'attach', 'return', 'review', 'store', 'host']);
  for (const task of conversation) {
    assert.equal(task.type, 'process'); assert.equal(task.command, 'node');
    assert.equal(task.presentation.echo, false); assert.equal(task.runOptions.runOn, undefined);
    assert.equal(task.dependsOn, undefined);
    assert.equal(task.options.env.WORKSPACE_CONVERSATION_ARCHIVE, '${input:conversationArchive}');
    assert.equal(task.options.env.WORKSPACE_CONVERSATION_REQUEST, '${input:conversationRequest}');
    assert.ok(!task.args.some(a => a.includes('${input:'))); // never in editor command/error echo
  }
  for (const input of tasks.inputs) { assert.equal(input.default, undefined); assert.equal(input.password, true); }
  const baseline = tasks.tasks.filter(t => !t.label.startsWith('Conversation:'));
  // Frozen pre-#58 objects, not a count-only check: setup/MCP/doctor semantics stay intact.
  assert.equal(createHash('sha256').update(JSON.stringify(baseline)).digest('hex'), '629bc88642f1530e5b9f3efd2bae9ee1dedaff7634b76c093dfb7b4afee5cb22');
});

test('real process argv preserves spaces, Unicode and shell metacharacters, without logging helper data', t => {
  const base = mkdtempSync(join(tmpdir(), 'workspace-58-argv-')); t.after(() => rmSync(base, { recursive: true, force: true }));
  const real = join(base, 'real'), linked = join(base, 'linked'); mkdirSync(real);
  symlinkSync(real, linked, process.platform === 'win32' ? 'junction' : 'dir');
  const special = process.platform === 'win32' ? 'кириллица & %PATH% ^ $ (x) !' : 'кириллица & $(); `touch INJECTED` "quote"';
  const dir = join(linked, special); mkdirSync(dir);
  const archive = join(dir, 'archive'); mkdirSync(archive);
  const kit = join(dir, 'kit'); mkdirSync(join(kit, 'tools'), { recursive: true });
  const body = 'DO_NOT_LOG_BODY';
  writeFileSync(join(kit, 'tools/conversation.ts'), `process.stdout.write(JSON.stringify({State:'Forked',argv:process.argv.slice(2),cwd:process.cwd(),Packet:${JSON.stringify(body)}}));process.stderr.write(${JSON.stringify(dir + ' PRIVATE_ERROR_BODY')});`);
  const request = put(join(dir, 'request.json'), { action: 'fork', text: body });
  const r = invoke(['--operation', 'fork', '--archive-root', archive, '--request-file', request], { AGENTKIT_HOME: kit }, dir);
  assert.equal(r.status, 0, r.stderr + r.stdout);
  const output = outputDir(request, r), value = JSON.parse(readFileSync(join(output, 'result.json'), 'utf8'));
  assert.deepEqual(value.argv, ['--archive-root', realpathSync(archive), '--request-file', realpathSync(request)]);
  // Windows can retain the junction spelling in process.cwd(); POSIX resolves
  // it. Both must still identify the caller's directory, never the kit/request.
  assert.equal(realpathSync(value.cwd), realpathSync(dir)); assert.equal(existsSync(join(dir, 'INJECTED')), false);
  for (const text of [body, 'PRIVATE_ERROR_BODY', dir]) assert.ok(!(r.stdout + r.stderr).includes(text));
  assert.match(readFileSync(join(output, 'stderr.txt'), 'utf8'), /PRIVATE_ERROR_BODY/);
  assert.match(readFileSync(join(output, 'packet.md'), 'utf8'), /DO_NOT_LOG_BODY/);
  if (process.platform !== 'win32') {
    assert.equal(statSync(output).mode & 0o777, 0o700);
    assert.equal(statSync(join(output, 'result.json')).mode & 0o777, 0o600);
  }
});

test('selection errors and mismatched actions fail before invoking a helper', t => {
  const base = mkdtempSync(join(tmpdir(), 'workspace-58-errors-')); t.after(() => rmSync(base, { recursive: true, force: true }));
  const f = fixture(base), kit = join(base, 'kit'); mkdirSync(join(kit, 'tools'), { recursive: true });
  const marker = join(base, 'INVOKED');
  writeFileSync(join(kit, 'tools/conversation.ts'), `import{writeFileSync}from'node:fs';writeFileSync(${JSON.stringify(marker)},'bad');`);
  const env = { AGENTKIT_HOME: kit };
  for (const args of [[], ['--operation', 'fork'], selected(f, 'review'), selected(f, 'fork', f.requests.store),
    selected(f, 'fork', join(base, 'absent.json')), selected(f, 'fork', f.requests.fork, ['--project', base]),
    ['--operation', 'fork', '--archive-root', root, '--request-file', f.requests.fork],
    selected(f, 'fork', f.requests.fork, ['--unexpected', 'PRIVATE'])]) {
    const r = invoke(args, env); assert.equal(r.status, 2); privacy(r, f);
  }
  assert.equal(existsSync(marker), false);
  assert.equal(readdirSync(f.base).filter(s => s.startsWith('.conversation-result-')).length, 0);
  // Realpath resolution prevents a linked public checkout bypassing the guard.
  const link = join(base, 'linked-workspace');
  symlinkSync(root, link, process.platform === 'win32' ? 'junction' : 'dir');
  const linked = invoke(['--operation', 'fork', '--archive-root', link, '--request-file', f.requests.fork], env);
  assert.equal(linked.status, 2); assert.match(linked.stderr, /PrivateSelectionRequired/);
  const missing = invoke(selected(f, 'fork'), { AGENTKIT_HOME: join(base, 'missing-kit') });
  assert.equal(missing.status, 2); assert.match(missing.stderr, /HelperUnavailable/);
});

test('project and explicit namespace stay separate arguments; fallback kit discovery uses the home', t => {
  const base = mkdtempSync(join(tmpdir(), 'workspace-58-target-')); t.after(() => rmSync(base, { recursive: true, force: true }));
  const f = fixture(base), kit = join(base, '.agent-kit'); mkdirSync(join(kit, 'tools'), { recursive: true });
  writeFileSync(join(kit, 'tools/conversation-memory.ts'), "console.log(JSON.stringify({State:'Proposed',argv:process.argv.slice(2)}));");
  const extras = ['--project', f.project, '--namespace', 'project/example/synthetic'];
  const r = invoke(selected(f, 'review', f.requests.review, extras), { AGENTKIT_HOME: '', HOME: base, USERPROFILE: base });
  assert.equal(r.status, 0, r.stdout + r.stderr); privacy(r, f);
  const value = JSON.parse(readFileSync(join(outputDir(f.requests.review, r), 'result.json'), 'utf8'));
  assert.deepEqual(value.argv, ['--archive-root', realpathSync(f.archive), '--request-file', realpathSync(f.requests.review),
    '--project', realpathSync(f.project), '--namespace', 'project/example/synthetic']);
});

test('helper failure and malformed output never become success or disclose diagnostics', t => {
  const base = mkdtempSync(join(tmpdir(), 'workspace-58-failures-')); t.after(() => rmSync(base, { recursive: true, force: true }));
  const f = fixture(base), kit = join(base, 'kit'); mkdirSync(join(kit, 'tools'), { recursive: true });
  const helper = join(kit, 'tools/conversation.ts');
  writeFileSync(helper, "process.stderr.write('SECRET_PATH: private failure body');process.exitCode=7;");
  const r = invoke(selected(f, 'fork'), { AGENTKIT_HOME: kit });
  assert.equal(r.status, 7); assert.match(r.stdout, /Unconfirmed/); assert.ok(!(r.stdout + r.stderr).includes('SECRET_PATH'));
  writeFileSync(helper, "console.log('malformed PRIVATE');");
  const malformed = invoke(selected(f, 'fork'), { AGENTKIT_HOME: kit });
  assert.equal(malformed.status, 1); assert.match(malformed.stdout, /Unconfirmed/); assert.ok(!malformed.stdout.includes('PRIVATE'));
});

const installed = process.env.AGENTKIT_HOME;
test('installed AgentKit: task argv exercises fork/attach/return, retries, memory off/test adapter and host fallback', { skip: !installed && 'Set AGENTKIT_HOME to the installed kit for integration tests.' }, t => {
  const base = mkdtempSync(join(tmpdir(), 'workspace-58-integration-')); t.after(() => rmSync(base, { recursive: true, force: true }));
  const f = fixture(base);
  const forkRequest = JSON.parse(readFileSync(f.requests.fork, 'utf8'));
  forkRequest.sources[0].file = relative(root, f.source);
  writeFileSync(f.requests.fork, '\uFEFF' + JSON.stringify(forkRequest)); // UTF-8 BOM + caller-relative source
  const env = { AGENTKIT_HOME: installed, AGENTKIT_MEMORYKIT_CONFIG: f.absentConfig };
  // Resolve the actual committed VS Code task args. This tests the CLI entry point,
  // not a VS Code GUI or Windows editor walkthrough.
  const taskRun = (operation, request = f.requests[operation], overrides = {}) => {
    const task = tasks.tasks.find(t => t.args?.includes(operation) && t.label.startsWith('Conversation:'));
    const substitutions = { '${workspaceFolder}': root, '${input:conversationArchive}': f.archive,
      '${input:conversationRequest}': request, '${input:conversationProject}': f.project };
    const args = task.args.map(a => Object.entries(substitutions).reduce((s, [key, v]) => s.replaceAll(key, v), a));
    const taskEnv = Object.fromEntries(Object.entries(task.options.env).map(([key, value]) => [key, substitutions[value] ?? value]));
    const r = spawnSync(process.execPath, args, { cwd: root, env: { ...process.env, ...env, ...taskEnv, ...overrides }, encoding: 'utf8', shell: false });
    privacy(r, f);
    const dir = outputDir(request, r);
    const value = existsSync(join(dir, 'result.json')) ? JSON.parse(readFileSync(join(dir, 'result.json'), 'utf8') || 'null') : null;
    return { ...r, value, dir };
  };
  const fork = taskRun('fork'); assert.equal(fork.status, 0, fork.stdout + fork.stderr); assert.equal(fork.value.State, 'Forked');
  const archived = join(f.archive, fork.value.Sources[0].path);
  assert.deepEqual(readFileSync(archived), readFileSync(f.source));
  assert.equal(taskRun('fork').value.Revision, 1);
  const attach = taskRun('attach'); assert.equal(attach.status, 0); assert.equal(attach.value.Revision, 2);
  assert.equal(taskRun('attach').value.Revision, 2); assert.equal(taskRun('fork').value.Revision, 1); // original receipt, not current revision
  const stale = put(join(f.base, 'stale.json'), { ...JSON.parse(readFileSync(f.requests.attach)), operationId: 'stale-operation' });
  const conflict = taskRun('attach', stale); assert.equal(conflict.status, 1); assert.match(readFileSync(join(conflict.dir, 'stderr.txt'), 'utf8'), /RevisionConflict/);
  const returned = taskRun('return'); assert.equal(returned.status, 0); assert.equal(returned.value.Persistence, 'ReadOnly');
  assert.match(returned.value.Packet, /codex:\/\/threads\/synthetic-parent/);
  assert.match(readFileSync(join(returned.dir, 'packet.md'), 'utf8'), /\[Note\]\(<file:/);
  const review = taskRun('review'); assert.equal(review.status, 0); assert.equal(review.value.proposals.length, 2);
  assert.deepEqual(review.value.proposals[0].attribution, { role: 'user', kind: 'exact' });
  assert.equal(existsSync(join(f.store, 'synthetic.json')), false);
  const off = taskRun('store'); assert.equal(off.status, 2); assert.equal(off.value.State, 'NotConfigured');
  assert.equal(existsSync(f.absentConfig), false); assert.equal(existsSync(join(f.store, 'synthetic.json')), false);
  // Only the test run explicitly selects this adapter. No real memory config is changed.
  const configured = { AGENTKIT_MEMORYKIT_CONFIG: f.config };
  const stored = taskRun('store', f.requests.store, configured); assert.equal(stored.status, 0, stored.stdout + stored.stderr);
  assert.equal(stored.value.Results.decision.Memory.status, 'candidate');
  assert.equal(stored.value.Results.decision.Memory.verification, 'unverified');
  assert.equal(taskRun('store', f.requests.store, configured).status, 0);
  const db = JSON.parse(readFileSync(join(f.store, 'synthetic.json'), 'utf8'));
  assert.equal(db.records.length, 1); assert.equal(db.records[0].metadata.status, 'candidate');
  for (const secret of ['UNSELECTED_SYNTHETIC_BODY', 'SYNTHETIC_PRIVATE_BOOKMARK', 'The later result is available.', 'Earlier turns']) assert.ok(!JSON.stringify(db).includes(secret));
  // Simulate a separate acceptance in the test adapter's current record. The
  // original operation receipt remains revision 1. A task retry must report the
  // actual accepted replay without itself performing or denying acceptance.
  db.records[0].metadata.status = 'accepted'; db.records[0].revision = 2;
  writeFileSync(join(f.store, 'synthetic.json'), JSON.stringify(db));
  const acceptedReplay = taskRun('store', f.requests.store, configured);
  assert.equal(acceptedReplay.status, 0);
  assert.equal(acceptedReplay.value.Results.decision.State, 'Replayed');
  assert.equal(acceptedReplay.value.Results.decision.Memory.status, 'accepted');
  assert.match(acceptedReplay.stdout, /Storage does not accept memories/);
  assert.ok(!acceptedReplay.stdout.includes('are candidates'));
  const host = taskRun('host'); assert.equal(host.status, 0); assert.equal(host.value.State, 'unsupported');
  assert.equal(host.value.Call, null); assert.match(host.value.Packet, /Selected outcome/);
  // Synthetic capability selection exercises the same outbox as a real host.
  // No native transport is invoked and this is not a live navigation smoke test.
  const supported = { ...JSON.parse(readFileSync(f.requests.host, 'utf8')), operationId: 'host-supported',
    capabilities: { host: 'codex', tools: ['mcp__codex_app__navigate_to_codex_page'], evidence: 'Synthetic contract test only.' },
    authorization: { navigate: true } };
  const prepareFile = put(join(f.base, 'host-supported.json'), supported);
  const prepared = taskRun('host', prepareFile); assert.equal(prepared.status, 0); assert.equal(prepared.value.State, 'prepared');
  assert.equal(prepared.value.Call, null);
  const dispatchFile = put(join(f.base, 'host-dispatch.json'), { schemaVersion: 1, action: 'dispatch', branchId: 'synthetic', operationId: 'host-supported' });
  const dispatch = taskRun('host', dispatchFile); assert.equal(dispatch.status, 0);
  assert.equal(dispatch.value.State, 'unknown'); assert.deepEqual(dispatch.value.Call, { tool: 'mcp__codex_app__navigate_to_codex_page', arguments: { threadId: 'synthetic-parent' } });
  assert.equal(taskRun('host', dispatchFile).value.Call, null); // no duplicate release
  const branch = JSON.parse(readFileSync(join(f.archive, fork.value.Manifest), 'utf8'));
  assert.equal(branch.revision, 2); assert.equal(branch.sources.length, 2);
});
