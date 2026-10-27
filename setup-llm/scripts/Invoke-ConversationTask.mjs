// Editor wiring only. AgentKit owns validation, provenance, replay and memory rules.
import { spawnSync } from 'node:child_process';
import { closeSync, existsSync, mkdtempSync, openSync, readFileSync, realpathSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';

const workspace = realpathSync(resolve(dirname(fileURLToPath(import.meta.url)), '../..'));
const operations = {
  fork: ['conversation.ts', ['fork']],
  attach: ['conversation.ts', ['attach']],
  return: ['conversation.ts', ['return']],
  review: ['conversation-memory.ts', ['propose']],
  store: ['conversation-memory.ts', ['store']],
  host: ['conversation-host.ts', ['prepare', 'dispatch', 'record', 'reconcile']],
};
const states = new Set(['Forked', 'Attached', 'Returned', 'Proposed', 'Stored', 'NotConfigured', 'Failed',
  'prepared', 'unsupported', 'unknown', 'success', 'failure']);
const codes = new Set(['RevisionConflict', 'OperationConflict', 'ArchiveLocked', 'IncompleteWrite', 'RecoveryConflict',
  'SourceChanged', 'QuoteMismatch', 'InvalidSpan', 'OccupiedPath', 'UnsafePath', 'InvalidRequest', 'BranchConflict',
  'SourceConflict', 'InvalidIndex', 'InvalidArchive', 'ReviewConflict', 'RequestConflict', 'IneligibleProposal',
  'InvalidStatement', 'NoNamespace', 'CliNotFound', 'CliFailed', 'UsageError', 'InvalidOutput', 'AuthorizationRequired',
  'ParentConflict', 'StateConflict', 'ObservationConflict']);
const within = (root, path) => { const rel = relative(root, path); return !rel || (!isAbsolute(rel) && rel !== '..' && !rel.startsWith('..' + sep)); };

export function runTask(argv, env = process.env) {
  let privateResult;
  try {
    const { values: v } = parseArgs({ args: argv, options: Object.fromEntries(
      ['operation', 'archive-root', 'request-file', 'project', 'namespace'].map(key => [key, { type: 'string' }])) });
    // Task inputs travel in the environment so even the editor's process-exit
    // message cannot print private selections as part of its command line.
    v['archive-root'] ??= env.WORKSPACE_CONVERSATION_ARCHIVE;
    v['request-file'] ??= env.WORKSPACE_CONVERSATION_REQUEST;
    v.project ??= env.WORKSPACE_CONVERSATION_PROJECT;
    const entry = operations[v.operation];
    if (!entry || !v['archive-root']?.trim() || !v['request-file']?.trim()) throw new Error('SelectionRequired');
    // Keep relative source paths relative to the caller, as AgentKit requires.
    const archive = realpathSync(resolve(v['archive-root']));
    const requestFile = realpathSync(resolve(v['request-file']));
    // This guard covers this public checkout (including linked paths), not every
    // public location. The operator must select private files; no remote probe runs.
    if (within(workspace, archive) || within(workspace, requestFile)) throw new Error('PrivateSelectionRequired');
    const request = JSON.parse(readFileSync(requestFile, 'utf8').replace(/^\uFEFF/, ''));
    // An editor entry point must never silently run a different action.
    // Everything else in the request is validated by the installed helper.
    if (!entry[1].includes(request?.action)) throw new Error('ActionMismatch');
    const memory = ['review', 'store'].includes(v.operation);
    if (memory && !v.project?.trim()) throw new Error('ProjectRequired');
    if (!memory && (v.project !== undefined || v.namespace !== undefined)) throw new Error('UnexpectedTarget');
    // An explicitly configured kit wins; never fall back from a broken override.
    const kit = resolve(env.AGENTKIT_HOME || join(env.HOME || env.USERPROFILE || homedir(), '.agent-kit'));
    const helper = join(kit, 'tools', entry[0]);
    if (!existsSync(helper)) throw new Error('HelperUnavailable');
    const [major, minor] = process.versions.node.split('.').map(Number);
    if (major < 22 || (major === 22 && minor < 18)) throw new Error('NodeUnavailable');
    const args = [helper, '--archive-root', archive, '--request-file', requestFile];
    if (memory) args.push('--project', realpathSync(resolve(v.project)));
    if (v.namespace !== undefined) args.push('--namespace', v.namespace);
    // A private result directory is reserved BEFORE invoking a mutating helper.
    // A new directory per attempt preserves earlier failures/uncertain outcomes.
    privateResult = mkdtempSync(join(dirname(requestFile), '.conversation-result-'));
    const output = join(privateResult, 'result.json');
    const descriptor = openSync(output, 'wx', 0o600);
    let child;
    try {
      // No shell, no text evaluation, no source/request bodies in argv or logs.
      // stdout streams to disk: large portable packets never overflow a buffer.
      child = spawnSync(process.execPath, args, { env, shell: false, stdio: ['ignore', descriptor, 'pipe'], maxBuffer: 1024 * 1024 });
    } finally { closeSync(descriptor); }
    // stderr may contain paths or source text. Retain it privately, never echo it.
    if (child.stderr?.length) writeFileSync(join(privateResult, 'stderr.txt'), child.stderr, { flag: 'wx', mode: 0o600 });
    let result;
    try { result = JSON.parse(readFileSync(output, 'utf8')); } catch { /* Outcome may be unknown, including after writes. */ }
    const state = states.has(result?.State) ? result.State : 'Unconfirmed';
    const diagnostic = /^([A-Za-z]+):/.exec(child.stderr?.toString('utf8') ?? '')?.[1];
    const code = codes.has(result?.code) ? result.code : codes.has(diagnostic) ? diagnostic : undefined;
    const status = child.error || child.signal || child.status === null ? 1 : child.status;
    // Preserve AgentKit's packet verbatim, with links to its canonical files.
    // Never render memory proposal bodies into the task terminal.
    if (typeof result?.Packet === 'string') {
      const links = ['Note', 'Manifest', 'Receipt'].filter(key => typeof result[key] === 'string').map(key =>
        `[${key}](<${pathToFileURL(resolve(archive, result[key])).href}>)`).join(' · ');
      writeFileSync(join(privateResult, 'packet.md'), `${links}\n\n${result.Packet}`, { flag: 'wx', mode: 0o600 });
    }
    console.log(`AgentKit: ${state}${code ? ' [' + code + ']' : ''}; exit ${status}.`);
    console.log(`Private result: ${privateResult.split(sep).at(-1)}/result.json (beside the selected request).`);
    if (typeof result?.Packet === 'string') console.log('Open packet.md there for branch/parent links and the portable handoff; archived-source links resolve from the canonical Note.');
    if (state === 'NotConfigured') console.log('Memory is off. No configuration was enabled; review the private result for guidance.');
    if (state === 'Proposed') console.log('Review individual proposals privately. Storage requires a separate request selecting IDs; acceptance remains /memory show|accept.');
    if (state === 'Stored') console.log('Selected writes are candidates, not accepted context. Inspect each private result.');
    if (state === 'Returned') console.log('Portable handoff only: navigate to the parent and copy the selected outcome manually.');
    if (v.operation === 'host') console.log('Native outbox only: inspect the private Call/receipt and use the canonical host workflow. No host tool was invoked by this task.');
    if (status !== 0 || state === 'Unconfirmed') console.log('Inspect private output/receipts; preserve request and IDs. A failure may follow writes; do not refresh revisions or create a new identity to retry.');
    return status || (state === 'Unconfirmed' ? 1 : 0);
  } catch (error) {
    const safe = new Set(['SelectionRequired', 'PrivateSelectionRequired', 'ActionMismatch', 'ProjectRequired',
      'UnexpectedTarget', 'HelperUnavailable', 'NodeUnavailable']);
    console.error(`Conversation task: ${safe.has(error.message) ? error.message : 'InvocationFailed'}.`);
    console.error(privateResult ? 'A helper may have run. Inspect the private result beside the selected request and retain its IDs before retrying.'
      : 'Select existing private archive/request paths and an installed AgentKit (AGENTKIT_HOME or ~/.agent-kit); check the task guide.');
    return 2;
  }
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) process.exitCode = runTask(process.argv.slice(2));
