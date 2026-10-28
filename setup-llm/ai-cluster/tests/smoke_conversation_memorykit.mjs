/** Opt-in: run the existing, built MemoryKit CLI/MCP against a disposable synthetic store.
 * Usage: node smoke_conversation_memorykit.mjs <trusted-existing-memorykit-checkout>
 * No package installation, host registration, personal store or configuration is used.
 */
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { createRequire } from 'node:module';
import { spawnSync } from 'node:child_process';

let client;
let temporary;
let stage = 'load-existing-runtime';
try {
  assert.equal(process.argv.length, 3);
  const root = realpathSync(resolve(process.argv[2]));
  const require = createRequire(join(root, 'package.json'));
  const { Client } = require('@modelcontextprotocol/client');
  const { StdioClientTransport } = require('@modelcontextprotocol/client/stdio');
  const cli = realpathSync(join(root, 'dist/cli/main.js'));
  temporary = mkdtempSync(join(realpathSync(tmpdir()), 'conversation-memorykit-smoke-'));
  const store = join(temporary, 'store');
  stage = 'initialize-synthetic-store';
  const initialized = spawnSync(process.execPath, [cli, 'init', store, '--json'], { encoding: 'utf8', timeout: 30000, windowsHide: true });
  assert.ok([0, 3].includes(initialized.status));
  stage = 'connect-mcp';
  client = new Client({ name: 'workspace-synthetic-smoke', version: '1.0.0' },
    { versionNegotiation: { mode: { pin: '2026-07-28' } } });
  await client.connect(new StdioClientTransport({ command: process.execPath, args: [cli, 'mcp', '--store', store], stderr: 'ignore' }));
  await client.discover();
  stage = 'list-tools';
  const discovery = await client.listTools();
  for (const name of ['memory_create', 'memory_get', 'memory_search', 'memory_update', 'memory_tombstone']) {
    assert.ok(discovery.tools.some(tool => tool.name === name));
  }
  async function call(name, args) {
    const result = await client.callTool({ name, arguments: args });
    assert.notEqual(result.isError, true);
    assert.ok(result.structuredContent);
    return result.structuredContent;
  }
  stage = 'create-replay-and-namespace-filtering';
  const input = { namespace: 'synthetic/workspace-smoke', kind: 'decision', content: 'Synthetic initial decision.', operationId: 'workspace-smoke-create' };
  const created = await call('memory_create', input);
  const replay = await call('memory_create', input);
  assert.equal(replay.memory.id, created.memory.id);
  const found = await call('memory_search', { namespaces: [input.namespace], states: ['active'] });
  assert.equal(found.items.length, 1);
  const other = await call('memory_search', { namespaces: ['synthetic/other-project'] });
  assert.equal(other.items.length, 0);
  stage = 'correct-and-tombstone';
  const updated = await call('memory_update', { id: created.memory.id, expectedRevision: created.memory.revision, content: 'Synthetic corrected decision.', operationId: 'workspace-smoke-correct' });
  const read = await call('memory_get', { id: created.memory.id });
  assert.equal(read.content, 'Synthetic corrected decision.');
  await call('memory_tombstone', { id: read.id, expectedRevision: updated.memory.revision, operationId: 'workspace-smoke-remove' });
  const removed = await call('memory_search', { namespaces: [input.namespace], states: ['active'] });
  assert.equal(removed.items.length, 0);
  await client.close();
  client = undefined;
  rmSync(temporary, { recursive: true, force: true });
  temporary = undefined;
  console.log(JSON.stringify({ status: 'supported', code: 'memorykit-cli-mcp-synthetic-smoke-passed', protocol: '2026-07-28', checks: ['discovery', 'create', 'replay', 'namespace-filter', 'read', 'correction', 'tombstone'], personalStoreOpened: false }));
} catch {
  // Do not log paths, server diagnostics, tool records or arbitrary exception text.
  console.error(JSON.stringify({ status: 'failed', code: 'memorykit-synthetic-smoke-failed', stage }));
  process.exitCode = 1;
} finally {
  let cleanupFailed = false;
  try { if (client) await client.close(); } catch { cleanupFailed = true; }
  try { if (temporary) rmSync(temporary, { recursive: true, force: true }); } catch { cleanupFailed = true; }
  if (cleanupFailed) {
    console.error(JSON.stringify({ status: 'failed', code: 'memorykit-synthetic-smoke-failed', stage: 'cleanup' }));
    process.exitCode = 1;
  }
}
