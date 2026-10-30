/** S1 acceptance tests: every profile is generated below an owned temp directory. */
import { test, type TestContext } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import { join, dirname, relative, resolve, sep } from 'node:path';
import { tmpdir } from 'node:os';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Manager, SettingsError, encode, jsonLoad, manifestPath, fingerprint, systemIO,
  replace, validateManifest, tomlLoad, type ManagerOptions, type Result } from '../../scripts/ai-settings.ts';

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const script = fileURLToPath(new URL('../../scripts/ai-settings.ts', import.meta.url));
const CANARY = 'CANARY PRIVATE VALUE DO NOT PUBLISH 9328';
const windows = process.platform === 'win32';
const permissionError = () => Object.assign(new Error(CANARY), { code: 'EACCES' });

function fixture(t: TestContext) {
  const temp = fs.realpathSync.native(tmpdir());
  const root = fs.mkdtempSync(join(temp, 'ai-settings-test-'));
  t.after(() => {
    const target = resolve(root);
    assert.equal(dirname(target), temp);
    assert.match(target.slice(temp.length + 1), /^ai-settings-test-[\w-]+$/);
    fs.rmSync(target, { recursive: true, force: true });
  });
  const claude = join(root, 'claude', 'settings.json'), codex = join(root, 'codex', 'config.toml');
  fs.mkdirSync(dirname(claude)); fs.mkdirSync(dirname(codex));
  fs.writeFileSync(claude, encode({ model: 'opus', env: { MAX_MCP_OUTPUT_TOKENS: '30000' } }));
  fs.writeFileSync(codex, 'model = "fixture-model"\nmodel_verbosity = "low"\n');
  const manager = (options: ManagerOptions = {}) => new Manager(root, structuredClone(manifest), options);
  const cli = (command: string, ...args: string[]) => {
    const run = spawnSync(process.execPath, [script, command, '--sandbox-root', root, ...args], { encoding: 'utf8', windowsHide: true });
    assert.equal(run.error, undefined);
    assert.equal(run.stderr, '');
    return { status: run.status, result: JSON.parse(run.stdout) as Result, output: run.stdout };
  };
  const mutate = () => {
    fs.writeFileSync(claude, encode({ model: 'sonnet', Keep: 1, keep: 2, env: { PRIVATE_KEY: CANARY } }));
    fs.writeFileSync(codex, 'model = "changed"\nmodel_verbosity = "high"\n');
  };
  const tree = () => {
    const files: Record<string, unknown> = {};
    function visit(path: string) {
      for (const entry of fs.readdirSync(path, { withFileTypes: true })) {
        const next = join(path, entry.name);
        if (entry.isDirectory()) visit(next);
        else if (entry.isFile()) files[relative(root, next)] = [fs.readFileSync(next).toString('base64'), fs.statSync(next, { bigint: true }).mtimeNs];
      }
    }
    visit(root); return files;
  };
  return { root, claude, codex, manager, cli, mutate, tree };
}
function outcomes(manager: Manager) { return manager.result.items.map(item => item.outcome); }
function completed(manager: Manager) {
  return fs.existsSync(manager.backups) ? fs.readdirSync(manager.backups)
    .filter(name => fs.existsSync(join(manager.backups, name, 'complete.json'))) : [];
}
function pwsh(command: string, environment: Record<string, string> = {}) {
  const run = spawnSync(process.env.AI_SETTINGS_PWSH || 'pwsh', ['-NoProfile', '-NonInteractive', '-Command', command],
    { encoding: 'utf8', windowsHide: true, env: { ...process.env, ...environment } });
  assert.equal(run.error, undefined);
  assert.equal(run.status, 0, run.stderr);
  return run.stdout.trim();
}

test('capture is idempotent and writes only the complete preference snapshot', t => {
  const f = fixture(t), before = f.tree();
  const first = f.cli('capture');
  assert.equal(first.status, 0); assert.equal(first.result.changed, true);
  const after = f.tree();
  assert.deepEqual(Object.keys(after).filter(p => !(p in before)), [join('repo', 'preferences.json')]);
  for (const path of Object.keys(before)) assert.deepEqual(after[path], before[path]);
  assert.equal(f.cli('capture').result.changed, false); assert.deepEqual(f.tree(), after);
});

test('classification precedence, unknown counts, attention exit policy and redaction', t => {
  const f = fixture(t); f.manager().capture();
  fs.writeFileSync(f.claude, encode({ a: 1, b: 2, c: {}, env: { MAX_MCP_OUTPUT_TOKENS: '30000' } }));
  assert.deepEqual(f.cli('status').result.attention.map(i => i.outcome), Array(3).fill('unclassified'));
  assert.equal(f.cli('status', '--fail-on-attention').status, 2);
  fs.writeFileSync(f.claude, encode({ hooks: { credential: CANARY }, env: { API_TOKEN: CANARY } }));
  const result = f.cli('status');
  assert.equal(result.result.attention.length, 1);
  assert.equal(result.result.attention[0].outcome, 'suspected-secret');
  assert.ok(!result.output.includes(CANARY)); assert.ok(!result.output.includes('API_TOKEN'));
});

test('WhatIf makes zero writes and marks security relevant changes', t => {
  const f = fixture(t);
  fs.writeFileSync(f.codex, 'model="fixture-model"\nsandbox_mode="read-only"\napproval_policy="on-request"\n');
  f.manager().capture();
  fs.writeFileSync(f.codex, 'model="other"\nsandbox_mode="danger-full-access"\napproval_policy="never"\n');
  const before = f.tree(), manager = f.manager(), result = manager.restore(true);
  assert.equal(result.changed, false); assert.equal(result.wouldChange, true);
  assert.equal(result.items.filter(i => i.outcome === 'would-change' && i.securityRelevant).length, 2);
  assert.deepEqual(f.tree(), before); assert.equal(fs.existsSync(manager.backups), false);
});

test('JSON restore preserves case sensitive unowned values and is idempotent', t => {
  const f = fixture(t); f.manager().capture(); f.mutate();
  assert.equal(f.manager().restore().changed, true);
  const data = JSON.parse(fs.readFileSync(f.claude, 'utf8'));
  assert.equal(data.Keep, 1); assert.equal(data.keep, 2);
  assert.deepEqual(data.env, { PRIVATE_KEY: CANARY, MAX_MCP_OUTPUT_TOKENS: '30000' });
  const before = f.tree(); assert.equal(f.manager().restore().changed, false); assert.deepEqual(f.tree(), before);
});

test('TOML editing preserves CRLF, comments, strings, arrays and nested tables', t => {
  const f = fixture(t); f.manager().capture();
  const suffix = 'notes = """fake\r\n[not.a.table]\r\nmodel="fake"\r\n"""\r\n' +
    "literal = '''[also.fake]\r\nmodel = 1\r\n'''\r\n" +
    'array = ["#", "[fake]",\r\n "\\\"quoted\\\""] # comment\r\n' +
    'inline = { value = "[fake]" }\r\n[profiles.test]\r\nmodel = "nested"\r\n';
  fs.writeFileSync(f.codex, '  "model"  = "changed"  # Keep comment\r\n' + suffix);
  f.manager().restore();
  const result = fs.readFileSync(f.codex, 'utf8');
  assert.ok(result.startsWith('  "model"  = "fixture-model"  # Keep comment\r\n'));
  assert.equal(result.replace('  "model"  = "fixture-model"  # Keep comment\r\n', '')
    .replace('"model_verbosity" = "low"\r\n', ''), suffix);
});

test('escaped TOML keys and unowned non finite TOML values survive', t => {
  const f = fixture(t); f.manager().capture();
  fs.writeFileSync(f.codex, '"mo\\u0064el" = "changed" # keep\nunowned = nan\n');
  f.manager().restore();
  assert.ok(fs.readFileSync(f.codex, 'utf8').startsWith('"mo\\u0064el" = "fixture-model" # keep\nunowned = nan\n'));
});

test('unsupported owned TOML forms are refused in preflight without writes', t => {
  const f = fixture(t); f.manager().capture();
  for (const raw of ['model.part="x"', 'model={part="x"}', 'model="x"\nmodel="y"',
    'model="""x"""', "model='''x'''", '[model]\nx="x"', 'model=["x"]', '\uFEFFmodel="x"']) {
    fs.writeFileSync(f.codex, raw); const before = f.tree();
    assert.throws(() => f.manager().restore(), SettingsError); assert.deepEqual(f.tree(), before);
  }
});

test('three optimistic conflicts abort and roll back the earlier target', t => {
  const f = fixture(t); f.manager().capture(); f.mutate(); const before = fs.readFileSync(f.claude), attempts: number[] = [];
  const manager = f.manager({ hook: (event, attempt, path) => {
    if (event === 'before-check' && path === f.codex) { attempts.push(attempt); fs.appendFileSync(path, '# race\n'); }
  } });
  assert.throws(() => manager.restore(), /concurrent-modification/);
  assert.deepEqual(attempts, [0, 1, 2]); assert.deepEqual(fs.readFileSync(f.claude), before);
  assert.ok(outcomes(manager).includes('rolled-back'));
});

test('one precheck conflict rebases the plan and preserves an external unowned edit', t => {
  const f = fixture(t); f.manager().capture(); f.mutate();
  f.manager({ hook: (event, attempt, path) => {
    if (event === 'before-check' && path === f.codex && attempt === 0) fs.appendFileSync(path, 'external=42\n');
  } }).restore();
  assert.equal(tomlLoad(fs.readFileSync(f.codex, 'utf8')).external, 42n);
});

test('the known check to replace race is observable rather than claimed as CAS', t => {
  const f = fixture(t); f.manager().capture(); f.mutate();
  f.manager({ hook: (event, _attempt, path) => {
    if (event === 'after-check' && path === f.codex) fs.appendFileSync(path, 'external=42\n');
  } }).restore();
  assert.equal(Object.hasOwn(tomlLoad(fs.readFileSync(f.codex, 'utf8')), 'external'), false);
});

test('post write overwrite is preserved and reported as a rollback conflict', t => {
  const f = fixture(t); f.manager().capture(); f.mutate();
  const external = encode({ external: CANARY });
  const manager = f.manager({ hook: (event, _attempt, path) => {
    if (event === 'after-write' && path === f.claude) fs.writeFileSync(path, external);
  } });
  assert.throws(() => manager.restore(), /overwritten-after-write/);
  assert.deepEqual(fs.readFileSync(f.claude), external); assert.ok(outcomes(manager).includes('rollback-conflict'));
  assert.deepEqual(completed(manager), []); assert.equal(fs.readdirSync(manager.backups).length, 1);
});

test('rollback refuses to overwrite an externally edited earlier target', t => {
  const f = fixture(t); f.manager().capture(); f.mutate();
  const manager = f.manager({ hook: (event, _attempt, path) => {
    if (event === 'before-check' && path === f.codex) { fs.writeFileSync(f.claude, encode({ external: CANARY })); throw permissionError(); }
  } });
  assert.throws(() => manager.restore(), /CANARY/);
  assert.deepEqual(JSON.parse(fs.readFileSync(f.claude, 'utf8')), { external: CANARY });
  assert.ok(outcomes(manager).includes('rollback-conflict')); assert.deepEqual(completed(manager), []);
});

test('an actual Windows exclusive file lock rolls back the earlier target', { skip: !windows }, async t => {
  const f = fixture(t); f.manager().capture(); f.mutate(); const before = fs.readFileSync(f.claude);
  const ready = join(f.root, 'lock-ready'), release = join(f.root, 'lock-release');
  let child: ReturnType<typeof spawn> | undefined;
  const manager = f.manager({ hook: (event, _attempt, path) => {
    if (event !== 'after-write' || path !== f.claude) return;
    child = spawn('pwsh', ['-NoProfile', '-NonInteractive', '-Command',
      '$f=[IO.File]::Open($env:LOCK_TARGET,"Open","Read","None"); try {' +
      '[IO.File]::WriteAllText($env:LOCK_READY,"ready"); while (-not [IO.File]::Exists($env:LOCK_RELEASE)) {Start-Sleep -Milliseconds 50}} finally {$f.Dispose()}'],
    { windowsHide: true, stdio: 'ignore', env: { ...process.env, LOCK_TARGET: f.codex, LOCK_READY: ready, LOCK_RELEASE: release } });
    const deadline = Date.now() + 15000;
    while (!fs.existsSync(ready) && Date.now() < deadline) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 25);
    assert.equal(fs.existsSync(ready), true);
  } });
  try { assert.throws(() => manager.restore()); }
  finally {
    fs.writeFileSync(release, 'release');
    if (child) await new Promise<void>((done, reject) => {
      const timer = setTimeout(() => { child?.kill(); reject(new Error('Fixture lock holder did not exit')); }, 10000);
      child!.once('exit', () => { clearTimeout(timer); done(); });
    });
  }
  assert.deepEqual(fs.readFileSync(f.claude), before); assert.ok(outcomes(manager).includes('rolled-back'));
});

test('capture destination conflicts stop after three checks and preserve the external file', t => {
  const f = fixture(t); f.manager().capture(); fs.writeFileSync(f.claude, '{"model":"sonnet"}');
  const attempts: number[] = [], manager = f.manager({ hook: (event, attempt, path) => {
    if (event === 'capture-before-check') { attempts.push(attempt); fs.writeFileSync(path, '{"external":true}\n' + ' '.repeat(attempt)); }
  } });
  assert.throws(() => manager.capture(), /concurrent-modification/);
  assert.deepEqual(attempts, [0, 1, 2]); assert.deepEqual(JSON.parse(fs.readFileSync(manager.data, 'utf8')), { external: true });
});

test('mid read metadata changes are retried and bounded at three reads', t => {
  const f = fixture(t);
  for (const limit of [2, 99]) {
    let reads = 0;
    const io = { ...systemIO, read: (path: string) => {
      const raw = fs.readFileSync(path); reads++;
      if (reads <= limit) { const stat = fs.statSync(path); fs.utimesSync(path, stat.atime, new Date(stat.mtimeMs + 1000)); }
      return raw;
    } };
    if (limit === 2) assert.deepEqual(fingerprint(f.codex, io).raw, fs.readFileSync(f.codex));
    else assert.throws(() => fingerprint(f.codex, io), /concurrent-modification/);
    assert.equal(reads, 3);
  }
});

test('stat and read permission retries recover or stop at the bounded count', t => {
  const f = fixture(t);
  for (const operation of ['stat', 'read'] as const) for (const failures of [2, 99]) {
    let calls = 0;
    const io = { ...systemIO };
    if (operation === 'stat') io.stat = path => { if (++calls <= failures) throw permissionError(); return systemIO.stat(path); };
    else io.read = path => { if (++calls <= failures) throw permissionError(); return systemIO.read(path); };
    if (failures === 2) assert.deepEqual(fingerprint(f.codex, io).raw, fs.readFileSync(f.codex));
    else assert.throws(() => fingerprint(f.codex, io), /CANARY/);
    assert.equal(calls, operation === 'stat' && failures === 2 ? 4 : 3);
  }
});

test('transient read failures at restore stages recover without losing applied targets', t => {
  const f = fixture(t); f.manager().capture();
  for (const stage of ['after-write', 'before-check', 'after-check']) {
    f.mutate(); let remaining = 0, failures = 0;
    const manager = f.manager({ hook: (event, _attempt, path) => {
      if (event === stage && path === (stage === 'after-write' ? f.claude : f.codex)) remaining = 2;
    }, io: { read: path => {
      if (path === f.codex && remaining) { remaining--; failures++; throw permissionError(); }
      return fs.readFileSync(path);
    } } });
    const result = manager.restore(); assert.equal(failures, 2);
    assert.equal(result.items.filter(i => i.outcome === 'applied').length, 2);
    assert.equal(JSON.parse(fs.readFileSync(f.claude, 'utf8')).model, 'opus');
    assert.equal(tomlLoad(fs.readFileSync(f.codex, 'utf8')).model, 'fixture-model');
  }
});

test('exhausted read retries roll back the earlier target and retain the incomplete backup', t => {
  const f = fixture(t); f.manager().capture(); f.mutate(); const before = fs.readFileSync(f.claude);
  let armed = false, failures = 0;
  const manager = f.manager({ hook: (event, _attempt, path) => { if (event === 'after-write' && path === f.claude) armed = true; },
    io: { read: path => { if (armed && path === f.codex) { failures++; throw permissionError(); } return fs.readFileSync(path); } } });
  assert.throws(() => manager.restore(), /CANARY/); assert.equal(failures, 3);
  assert.deepEqual(fs.readFileSync(f.claude), before); assert.ok(outcomes(manager).includes('rolled-back'));
  assert.deepEqual(completed(manager), []); assert.equal(fs.readdirSync(manager.backups).length, 1);
});

test('Windows target DACL and inheritance survive restore and rollback', { skip: !windows }, t => {
  const f = fixture(t); f.manager().capture();
  const granted = spawnSync('icacls', [dirname(f.claude), '/grant', '*S-1-1-0:(OI)(CI)R'], { windowsHide: true });
  assert.equal(granted.status, 0);
  const inspect = '$a=Get-Acl -LiteralPath $env:FIXTURE_ACL; ' +
    '$s=$a.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::Access); ' +
    '[pscustomobject]@{Protected=$a.AreAccessRulesProtected; Rules=($s -replace "^D:[^(]*","D:")} | ConvertTo-Json -Compress';
  const restrict = '$a=[System.Security.AccessControl.FileSecurity]::new(); $a.SetAccessRuleProtection($true,$false); ' +
    '$sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User; ' +
    '$a.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($sid,"FullControl","Allow")); ' +
    'Set-Acl -LiteralPath $env:FIXTURE_ACL -AclObject $a; ' +
    'if ($env:FIXTURE_PROTECTED -ne "true") {& icacls $env:FIXTURE_ACL /inheritance:e | Out-Null; if ($LASTEXITCODE -ne 0) {exit 1}}; ';
  for (const protectedAcl of [true, false]) for (const rollback of [false, true]) {
    f.mutate(); const beforeBytes = fs.readFileSync(f.claude);
    const env = { FIXTURE_ACL: f.claude, FIXTURE_PROTECTED: String(protectedAcl) };
    const before = JSON.parse(pwsh(restrict + inspect, env));
    assert.equal(before.Protected, protectedAcl); assert.equal(before.Rules.includes(';;;WD)'), !protectedAcl);
    const manager = f.manager({ hook: (event, _attempt, path) => {
      if (rollback && event === 'before-check' && path === f.codex) throw permissionError();
    } });
    if (rollback) { assert.throws(() => manager.restore(), /CANARY/); assert.deepEqual(fs.readFileSync(f.claude), beforeBytes); assert.ok(outcomes(manager).includes('rolled-back')); }
    else { manager.restore(); assert.equal(JSON.parse(fs.readFileSync(f.claude, 'utf8')).model, 'opus'); }
    assert.deepEqual(JSON.parse(pwsh(inspect, env)), before);
    assert.deepEqual(fs.readdirSync(dirname(f.claude)).filter(name => name.startsWith('.ai-settings-')), []);
  }
});

test('DACL setup failure stages no private bytes and preserves the target', { skip: !windows }, t => {
  const f = fixture(t), before = fs.readFileSync(f.claude), inspected: Buffer[] = [];
  assert.throws(() => replace(f.claude, Buffer.from(CANARY), (_source, destination) => {
    inspected.push(fs.readFileSync(destination)); throw permissionError();
  }), /CANARY/);
  assert.deepEqual(inspected, [Buffer.alloc(0)]); assert.deepEqual(fs.readFileSync(f.claude), before);
  assert.deepEqual(fs.readdirSync(dirname(f.claude)).filter(name => name.startsWith('.ai-settings-')), []);
});

test('invalid JSON numbers never overwrite the previous snapshot', t => {
  const f = fixture(t); f.manager().capture(); const before = fs.readFileSync(f.manager().data);
  for (const raw of ['{"autoCompactWindow":1e400}', '{"x":-1e400}', '{"x":NaN}', '{"x":Infinity}']) {
    fs.writeFileSync(f.claude, raw); const run = f.cli('capture');
    assert.equal(run.status, 1); assert.equal(run.result.error, 'invalid-json-number');
    assert.deepEqual(fs.readFileSync(f.manager().data), before);
  }
});

test('TOML insertion precedes comments attached to the first table header', t => {
  const f = fixture(t); f.manager().capture();
  fs.writeFileSync(f.codex, 'model = "fixture-model"\n\n# Profile notes\n[profiles.a]\nmodel = "nested"\n');
  f.manager().restore();
  assert.equal(fs.readFileSync(f.codex, 'utf8'), 'model = "fixture-model"\n"model_verbosity" = "low"\n\n# Profile notes\n[profiles.a]\nmodel = "nested"\n');
});

test('snapshot versions, actions, null values and missing destinations fail before writes', t => {
  const f = fixture(t); f.manager().capture(); const original = fs.readFileSync(f.manager().data);
  for (const change of [
    (s: any) => { s.manifestVersion = true; }, (s: any) => { s.manifestVersion = 999; },
    (s: any) => { Object.assign(s.targets.claude[0], { action: 'set', value: null }); },
    (s: any) => { s.targets.claude[0].action = 'delete'; },
    (s: any) => { s.targets.claude.pop(); },
  ]) {
    const snapshot = JSON.parse(original.toString()); change(snapshot); fs.writeFileSync(f.manager().data, encode(snapshot));
    const before = f.tree(); assert.throws(() => f.manager().restore(), SettingsError); assert.deepEqual(f.tree(), before);
  }
  fs.writeFileSync(f.manager().data, original); fs.unlinkSync(f.codex);
  const before = f.tree(); assert.throws(() => f.manager().restore(), /missing-target/); assert.deepEqual(f.tree(), before);
});

test('replace failure rolls back and rollback failure is reported separately', t => {
  const f = fixture(t); f.manager().capture();
  for (const failRollback of [false, true]) {
    f.mutate(); const before = fs.readFileSync(f.claude); let claudeCalls = 0, codexCalls = 0;
    const manager = f.manager({ io: { replace: (path, raw) => {
      if (path === f.codex) { codexCalls++; throw permissionError(); }
      if (path === f.claude && ++claudeCalls > 1 && failRollback) throw permissionError();
      replace(path, raw);
    } } });
    assert.throws(() => manager.restore(), /replace-failed/); assert.equal(codexCalls, 3);
    assert.ok(outcomes(manager).includes(failRollback ? 'rollback-failed' : 'rolled-back'));
    if (!failRollback) assert.deepEqual(fs.readFileSync(f.claude), before);
  }
});

test('malformed second target aborts preflight without writes or leaked diagnostics', t => {
  const f = fixture(t); f.manager().capture(); f.mutate(); fs.writeFileSync(f.codex, `bad = [ "${CANARY}"`);
  const before = f.tree(), run = f.cli('restore', '--force');
  assert.equal(run.status, 1); assert.equal(run.result.error, 'malformed-toml');
  assert.ok(!run.output.includes(CANARY)); assert.deepEqual(f.tree(), before);
});

test('invalid owned JSON types, parents, ranges, duplicate keys and malformed input are rejected', t => {
  const f = fixture(t); f.manager().capture(); const snapshot = fs.readFileSync(f.manager().data);
  for (const raw of ['{"model":null}', '{"autoCompactWindow":true}', '{"autoCompactWindow":1}',
    '{"model":{}}', '{"env":[]}', '{"model":"opus","model":"sonnet"}', '{bad']) {
    fs.writeFileSync(f.claude, raw); assert.equal(f.cli('capture').status, 1);
    assert.deepEqual(fs.readFileSync(f.manager().data), snapshot);
  }
  fs.unlinkSync(f.claude); assert.equal(f.cli('capture').result.error, 'missing-target');
});

test('explicit unset actions remove owned leaves and preserve neighboring unowned data', t => {
  const f = fixture(t); fs.writeFileSync(f.claude, '{}'); fs.writeFileSync(f.codex, ''); f.manager().capture();
  fs.writeFileSync(f.claude, '{"model":"opus","env":{"MAX_MCP_OUTPUT_TOKENS":"30000","OTHER":"keep"}}');
  fs.writeFileSync(f.codex, 'model="other"\n[profiles.a]\nmodel="nested"\n'); f.manager().restore();
  assert.deepEqual(JSON.parse(fs.readFileSync(f.claude, 'utf8')), { env: { OTHER: 'keep' } });
  assert.deepEqual(tomlLoad(fs.readFileSync(f.codex, 'utf8')), tomlLoad('[profiles.a]\nmodel="nested"\n'));
  assert.equal(f.manager().restore().changed, false);
});

test('secret canaries are absent from reports and snapshot, and invalid owned values are sanitized', t => {
  const f = fixture(t);
  fs.writeFileSync(f.claude, encode({ model: 'opus', env: { API_TOKEN: CANARY }, mcpServers: { secret: CANARY }, unknown: CANARY }));
  fs.writeFileSync(f.codex, `model="fixture-model"\nunknown="${CANARY}"\n[mcp_servers.fixture.http_headers]\nAuthorization="${CANARY}"\n`);
  fs.writeFileSync(join(f.root, 'claude', 'credentials.json'), CANARY);
  fs.writeFileSync(join(f.root, 'claude', 'claude_desktop_config.json'), CANARY);
  for (const command of ['capture', 'status', 'restore']) {
    const run = f.cli(command, '--force'); assert.equal(run.status, 0); assert.ok(!run.output.includes(CANARY));
    assert.ok(run.result.coverage?.notInspected.includes('claude-desktop'));
  }
  assert.ok(!fs.readFileSync(f.manager().data, 'utf8').includes(CANARY));
  fs.writeFileSync(f.claude, encode({ model: CANARY })); const run = f.cli('capture');
  assert.equal(run.status, 1); assert.ok(!run.output.includes(CANARY));
  for (const name of fs.readdirSync(dirname(f.manager().data))) assert.ok(!fs.readFileSync(join(dirname(f.manager().data), name), 'utf8').includes(CANARY));
});

test('status reports absent snapshot and bad targets without writes', t => {
  const f = fixture(t); fs.unlinkSync(f.claude); fs.writeFileSync(f.codex, 'bad=['); const before = f.tree();
  const result = f.manager().status(); assert.equal(result.attention.length, 3); assert.deepEqual(f.tree(), before);
});

test('running Codex blocks restore and preview until Force is supplied', t => {
  const f = fixture(t); f.manager().capture(); f.mutate(); const before = f.tree();
  for (const preview of [true, false]) assert.throws(() => f.manager({ codexRunning: () => true }).restore(preview), /codex-running/);
  assert.deepEqual(f.tree(), before); assert.equal(f.manager({ codexRunning: () => true }).restore(false, true).changed, true);
});

test('outside paths, temp root, repository backups and symbolic links are rejected', t => {
  const f = fixture(t), before = f.tree();
  for (const options of [{ claudeHome: join(f.root, '..', '.claude') }, { codexHome: join(tmpdir(), '.codex') },
    { backupRoot: join(f.root, 'repo', 'backup') }]) assert.throws(() => f.manager(options), SettingsError);
  assert.throws(() => new Manager(tmpdir(), manifest), /sandbox-must-be-existing-temp-child/);
  const link = join(f.root, 'alias'); fs.symlinkSync(dirname(f.claude), link, windows ? 'junction' : 'dir');
  assert.throws(() => f.manager({ claudeHome: link }), /path-outside-sandbox-or-linked/);
  assert.deepEqual(f.tree(), before);
});

for (const [label, options] of [
  ['data file inside Codex home', (root: string) => ['--data-path', join(root, 'codex', 'preferences.json')]],
  ['backups inside Claude home', (root: string) => ['--backup-root', join(root, 'claude', 'backup')]],
  ['shared profile homes', (root: string) => ['--codex-home', join(root, 'claude')]],
  ['data file nested inside Claude home', (root: string) => ['--data-path', join(root, 'claude', 'nested', 'preferences.json')]],
] as const) test(`${label} is rejected before reads or writes`, t => {
  const f = fixture(t), before = f.tree(), run = f.cli('capture', ...options(f.root));
  assert.equal(run.status, 1); assert.equal(run.result.error, 'overlapping-sandbox-paths'); assert.deepEqual(f.tree(), before);
});

test('hostile app environment overrides never cause reads outside the sandbox', t => {
  const f = fixture(t), previousCodex = process.env.CODEX_HOME, previousClaude = process.env.CLAUDE_CONFIG_DIR;
  process.env.CODEX_HOME = join(f.root, '..', 'hostile-codex'); process.env.CLAUDE_CONFIG_DIR = join(f.root, '..', 'hostile-claude');
  try {
    const options = { io: { read: (path: string) => { assert.ok(path.startsWith(f.root + sep)); return fs.readFileSync(path); } } };
    f.manager(options).capture(); f.manager(options).status(); f.manager(options).restore(true);
  } finally {
    if (previousCodex === undefined) delete process.env.CODEX_HOME; else process.env.CODEX_HOME = previousCodex;
    if (previousClaude === undefined) delete process.env.CLAUDE_CONFIG_DIR; else process.env.CLAUDE_CONFIG_DIR = previousClaude;
  }
});

test('capture does not mutate the Git index, current branch or refs', t => {
  const f = fixture(t), repo = dirname(f.manager().data); fs.mkdirSync(repo);
  const git = (...args: string[]) => { const run = spawnSync('git', ['-C', repo, ...args], { encoding: 'utf8', windowsHide: true }); assert.equal(run.status, 0, run.stderr); return run.stdout; };
  git('init', '--quiet'); fs.writeFileSync(join(repo, 'unrelated.txt'), 'keep'); git('add', 'unrelated.txt');
  const before = fs.readFileSync(join(repo, '.git', 'index')), head = fs.readFileSync(join(repo, '.git', 'HEAD'));
  f.manager().capture(); assert.deepEqual(fs.readFileSync(join(repo, '.git', 'index')), before);
  assert.deepEqual(fs.readFileSync(join(repo, '.git', 'HEAD')), head);
  const refs = spawnSync('git', ['-C', repo, 'show-ref', '--head'], { encoding: 'utf8', windowsHide: true });
  assert.equal(refs.status, 1); assert.equal(refs.stdout, ''); assert.equal(refs.stderr, '');
});

test('retention keeps five completed private backups and retains failed runs', t => {
  const f = fixture(t); f.manager().capture();
  const failed = join(f.manager().backups, 'failed-run'); fs.mkdirSync(failed, { recursive: true }); fs.writeFileSync(join(failed, 'settings.json'), CANARY);
  for (let i = 0; i < 7; i++) { f.mutate(); f.manager().restore(); }
  assert.equal(completed(f.manager()).length, 5); assert.equal(fs.readFileSync(join(failed, 'settings.json'), 'utf8'), CANARY);
  if (!windows) {
    assert.equal(fs.statSync(f.manager().backups).mode & 0o777, 0o700);
    for (const name of completed(f.manager())) {
      assert.equal(fs.statSync(join(f.manager().backups, name)).mode & 0o777, 0o700);
      assert.equal(fs.statSync(join(f.manager().backups, name, 'settings.json')).mode & 0o777, 0o600);
    }
  }
});

test('Windows backup root removes existing broad grants and disables inheritance', { skip: !windows }, t => {
  const f = fixture(t); f.manager().capture(); f.mutate(); const path = f.manager().backups; fs.mkdirSync(path);
  assert.equal(spawnSync('icacls', [path, '/grant', '*S-1-1-0:(OI)(CI)F'], { windowsHide: true }).status, 0);
  f.manager().restore();
  const info = JSON.parse(pwsh('$a=Get-Acl -LiteralPath $env:FIXTURE_ACL; [pscustomobject]@{Protected=$a.AreAccessRulesProtected; Count=@($a.Access).Count; Sid=$a.Access[0].IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value; Current=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value} | ConvertTo-Json -Compress', { FIXTURE_ACL: path }));
  assert.equal(info.Protected, true); assert.equal(info.Count, 1); assert.equal(info.Sid, info.Current);
});

test('manifest counts and strict negative schema cases match the reviewed contract', () => {
  assert.deepEqual(validateManifest(manifest), { owned: 24, ignored: 18, inspectionSpaces: 2 });
  const changes: ((m: any) => void)[] = [
    m => { m.version = true; }, m => { m.targets.other = {}; }, m => { m.targets.claude.owned.push(m.targets.claude.owned[0]); },
    m => { m.targets.claude.ignored.push({ path: ['env'], reason: 'overlaps' }); },
    m => { m.targets.codex.owned[0].type = 'table'; }, m => { m.targets.codex.owned[0].path = ['table', 'model']; },
    m => { m.targets.claude.owned.find((r: any) => r.type === 'integer').min = 99999999; },
    m => { m.targets.claude.owned[0].pattern = '['; }, m => { m.targets.claude.owned[0].extra = true; },
    m => { m.targets.claude.inspect.push(['env']); }, m => { m.targets.codex.owned[0].securityRelevant = 'true'; },
    m => { m.targets.claude.owned[1].values = []; },
  ];
  for (const change of changes) { const copy = structuredClone(manifest); change(copy); assert.throws(() => validateManifest(copy), SettingsError); }
});

test('unowned JSON integers and decimal precision survive without JavaScript rounding', t => {
  const f = fixture(t); f.manager().capture();
  fs.writeFileSync(f.claude, '{"model":"sonnet","large":900719925474099312345,"huge":' + '9'.repeat(400) + ',"negativeZero":-0,"decimal":0.1234567890123456789012345}');
  f.manager().restore(); const text = fs.readFileSync(f.claude, 'utf8');
  assert.match(text, /900719925474099312345/); assert.match(text, /0\.1234567890123456789012345/);
  assert.ok(text.includes('9'.repeat(400))); assert.match(text, /"negativeZero": -0/);
  assert.equal(f.manager().restore().changed, false);
});

test('prototype named unowned keys remain ordinary data without prototype pollution', t => {
  const f = fixture(t); f.manager().capture();
  fs.writeFileSync(f.claude, '{"model":"sonnet","__proto__":{"polluted":true},"constructor":{"prototype":{"polluted":true}}}');
  f.manager().restore(); const data = jsonLoad(fs.readFileSync(f.claude)) as Record<string, unknown>;
  assert.equal(Object.hasOwn(data, '__proto__'), true); assert.deepEqual(data.__proto__, { polluted: true });
  assert.equal(Object.hasOwn({}, 'polluted'), false); assert.equal(({} as Record<string, unknown>).polluted, undefined);
});

test('full TOML parser rejects invalid dates, invalid Unicode and duplicate table definitions', t => {
  const f = fixture(t); f.manager().capture();
  for (const raw of ['x=2024-02-30', 'x="\\uD800"', 'x="\\U00110000"', '[x]\na=1\n[x]\nb=2']) {
    fs.writeFileSync(f.codex, raw); const before = f.tree();
    assert.equal(f.cli('restore', '--force').result.error, 'malformed-toml'); assert.deepEqual(f.tree(), before);
  }
});

test('unowned TOML dates, times, large integers and special floats survive a restore', t => {
  const f = fixture(t); f.manager().capture();
  const suffix = 'date=2024-02-29\ntime=12:34:56.123456\nlocal=2024-02-29T12:34:56.123456\n' +
    'offset=2024-02-29T12:34:56.123456+02:00\nlarge=9223372036854775807\nvalues=[inf,-inf,nan]\n';
  fs.writeFileSync(f.codex, 'model="changed"\nmodel_verbosity="high"\n' + suffix);
  assert.equal(f.manager().restore().changed, true);
  assert.ok(fs.readFileSync(f.codex, 'utf8').endsWith(suffix));
  assert.equal(f.manager().restore().changed, false);
});

test('UTF8 decoding is strict and BOM is refused for either target', t => {
  const f = fixture(t); f.manager().capture();
  for (const path of [f.claude, f.codex]) {
    const original = fs.readFileSync(path);
    for (const raw of [Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), original]), Buffer.from([0xFF, 0xFE, 0x00])]) {
      fs.writeFileSync(path, raw); assert.equal(f.cli('capture').result.error, 'unsupported-encoding');
    }
    fs.writeFileSync(path, original);
  }
});

test('CLI rejects unsupported arguments and WhatIf misuse with sanitized JSON', t => {
  const f = fixture(t), before = f.tree();
  assert.equal(f.cli('capture', '--what-if').result.error, 'what-if-requires-restore');
  assert.equal(f.cli('status', '--what-if').result.error, 'what-if-requires-restore');
  const run = f.cli('capture', '--' + CANARY); assert.equal(run.status, 1); assert.ok(!run.output.includes(CANARY));
  assert.deepEqual(f.tree(), before);
});
