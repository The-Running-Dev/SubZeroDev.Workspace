// Synthetic fixtures only. This adapter is NOT a MemoryKit installation or store.
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';
import { spawnSync } from 'node:child_process';

export function fixture(directory) {
  const base = mkdtempSync(join(directory, 'workspace-58-'));
  const put = (name, content) => { const path = join(base, name); writeFileSync(path, content, { mode: 0o600 }); return path; };
  // Portable filename characters; includes PowerShell/cmd/bash metacharacters.
  const archive = join(base, 'private Архив & $ (notes)');
  const project = join(base, 'project с пробелами & $ (test)');
  const store = join(base, 'synthetic adapter & данные');
  for (const dir of [archive, project, store]) mkdirSync(dir, { mode: 0o700 });
  // Local synthetic origin metadata only; no network, commit or push.
  for (const args of [['init', project], ['-C', project, 'remote', 'add', 'origin', 'https://example.invalid/fixture/synthetic.git']]) {
    const r = spawnSync('git', args, { shell: false, encoding: 'utf8' });
    if (r.status !== 0) throw new Error('Synthetic fixture requires Git.');
  }
  writeFileSync(join(archive, 'INDEX.md'), '# Synthetic Notes\n<!-- notes -->\n');
  const raw = 'Use portable handoffs.\r\nUNSELECTED_SYNTHETIC_BODY\n';
  const later = 'Later result: готово & $(); `never execute`\n';
  const source = put('excerpt & $ (данные).txt', raw);
  const source2 = put('later & $ (данные).txt', later);
  const statement = { role: 'user', kind: 'exact', text: 'Use portable handoffs.', refs: [{ sourceId: 'excerpt', startByte: 0, endByte: Buffer.byteLength('Use portable handoffs.') }] };
  const fork = { schemaVersion: 1, action: 'fork', branchId: 'synthetic', operationId: 'fork-1', date: '2026-10-27',
    parent: { uri: 'codex://threads/synthetic-parent', bookmark: 'SYNTHETIC_PRIVATE_BOOKMARK', question: 'Which handoff?' },
    sources: [{ id: 'excerpt', file: source, coverage: 'Synthetic excerpt only', missing: ['Earlier turns'], uncertainty: [] }], handoff: [statement] };
  const attach = { schemaVersion: 1, action: 'attach', branchId: 'synthetic', operationId: 'attach-1', expectedRevision: 1,
    sources: [{ id: 'later', file: source2, coverage: 'Synthetic later result', missing: [], uncertainty: [] }],
    handoff: [{ role: 'assistant', kind: 'summary', text: 'The later result is available.', refs: [{ sourceId: 'later', startByte: 0, endByte: Buffer.byteLength(later) }] }] };
  const returning = { schemaVersion: 1, action: 'return', branchId: 'synthetic', expectedRevision: 2, outcome: [attach.handoff[0]] };
  const propose = { schemaVersion: 1, action: 'propose', branchId: 'synthetic', reviewId: 'review-1', expectedRevision: 2,
    proposals: [{ id: 'decision', kind: 'decision', statementIndex: 0, statement: 'source' },
      { id: 'summary', kind: 'handoff', statementIndex: 1, statement: 'generated' }] };
  const storing = { schemaVersion: 1, action: 'store', branchId: 'synthetic', reviewId: 'review-1', selected: ['decision'] };
  const host = { schemaVersion: 1, action: 'prepare', branchId: 'synthetic', operationId: 'host-return-1', expectedRevision: 2,
    intent: 'return', outcome: returning.outcome, capabilities: { host: 'vscode', tools: [], evidence: 'Synthetic test; native APIs unavailable.' } };
  const requests = {};
  for (const [key, request] of Object.entries({ fork, attach, return: returning, review: propose, store: storing, host })) {
    requests[key] = put(`${key} & преглед.json`, JSON.stringify(request));
  }
  const cli = put('synthetic-memory-cli.mjs', `
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
const [verb, ...args] = process.argv.slice(2), flags = {}, pos = [];
for (let i = 0; i < args.length; i++) {
  const m = /^--([^=]+)=([^]*)$/.exec(args[i]);
  if (m) flags[m[1]] = m[2];
  else if (args[i].startsWith('--')) flags[args[i].slice(2)] = args[i + 1] && !args[i + 1].startsWith('--') ? args[++i] : 'true';
  else pos.push(args[i]);
}
const file = join(flags.store, 'synthetic.json');
const db = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : { records: [], ops: {} };
const ok = value => { process.stdout.write(JSON.stringify(value)); process.exit(0); };
const fail = code => { process.stderr.write(JSON.stringify({ code, title: code })); process.exit(1); };
if (verb === 'get') { const r = db.records.find(r => r.id === pos[0]); r ? ok(r) : fail('NotFound'); }
if (verb === 'search') ok({ items: db.records.filter(r => r.namespace === flags.namespace && (!flags.metadata || Object.entries(JSON.parse(flags.metadata)).every(([k, v]) => r.metadata[k] === v))), nextCursor: null });
const identity = flags['operation-id'];
if (db.ops[identity]) ok(db.ops[identity]);
if (verb !== 'create') fail('InvalidCommand'); // Acceptance deliberately unsupported by this test adapter.
const memory = { id: 'S' + (db.records.length + 1), namespace: flags.namespace, kind: flags.kind, content: flags.content,
  metadata: JSON.parse(flags.metadata), provenance: JSON.parse(flags.provenance), revision: 1, state: 'active', supersededBy: [], updatedAt: new Date().toISOString() };
db.records.push(memory);
const out = { operationId: identity, memory, history: 'persisted' }; db.ops[identity] = out;
writeFileSync(file, JSON.stringify(db)); ok(out);
`);
  const config = put('synthetic-memorykit.json', JSON.stringify({ cli, store, capture: false, context: false }));
  const absentConfig = join(base, 'absent-memorykit.json');
  const result = { base, archive, project, store, source, source2, config, absentConfig, requests };
  put('fixture.json', JSON.stringify(result, null, 2));
  return result;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { values } = parseArgs({ options: { directory: { type: 'string' } } });
  if (!values.directory) throw new Error('Supply an existing private --directory for synthetic fixtures.');
  const result = fixture(values.directory);
  // The caller captures this JSON privately; it is not a task log.
  process.stdout.write(JSON.stringify(result));
}
