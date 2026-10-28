import { spawnSync } from 'node:child_process';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join, isAbsolute } from 'node:path';
import { homedir } from 'node:os';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

// Transport only. AgentKit owns validation, revisions, replay and candidate semantics.
export function run(args, env = process.env) {
  try {
    const names = ['operation', 'archive-root', 'request-file'];
    if (args.length !== 6 || args.some((v, i) => i % 2 === 0 && v !== `--${names[i / 2]}`)) throw Error();
    if (!isAbsolute(args[3]) || !isAbsolute(args[5])) throw Error();
    const operation = args[1], archive = resolve(args[3]), requestFile = resolve(args[5]);
    readFileSync(join(archive, 'INDEX.md')); // An explicit existing archive; never initialize one.
    const routes = { fork: ['conversation.ts', 'fork'], attach: ['conversation.ts', 'attach'], return: ['conversation.ts', 'return'], review: ['conversation-memory.ts', 'propose'], store: ['conversation-memory.ts', 'store'], host: ['conversation-host.ts', null] };
    const route = routes[operation];
    if (!route) throw Error();
    const request = JSON.parse(readFileSync(requestFile, 'utf8').replace(/^\uFEFF/, ''));
    if (route[1] && request.action !== route[1]) throw Error();
    const kit = env.AGENTKIT_HOME || join(homedir(), '.agent-kit');
    const tool = join(kit, 'tools', route[0]);
    readFileSync(tool); // Fail before starting when the selected installed kit lacks the tool.
    const child = spawnSync(process.execPath, [tool, '--archive-root', archive, '--request-file', requestFile, ...(operation === 'review' || operation === 'store' ? ['--project', archive] : [])], { env, shell: false, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024, timeout: 120000 });
    if (child.error || child.signal) return { exitCode: 1, report: { State: 'Failed', Code: 'AgentKitProcessFailed', Recovery: 'Inspect the private archive before retrying; an interrupted operation may have persisted.' } };
    let result;
    try { result = JSON.parse(child.stdout); } catch { return { exitCode: 1, report: { State: 'Failed', Code: 'AgentKitOutputUnavailable', Recovery: 'Run the selected AgentKit tool privately for diagnostics; inspect the archive before retrying.' } }; }
    const dir = join(archive, '.workspace-conversation-results');
    mkdirSync(dir, { recursive: true });
    const bytes = JSON.stringify(result, null, 2) + '\n';
    const file = join(dir, createHash('sha256').update(bytes).digest('hex') + '.json');
    try { writeFileSync(file, bytes, { flag: 'wx', mode: 0o600 }); } catch (error) {
      if (error.code !== 'EEXIST' || readFileSync(file, 'utf8') !== bytes) throw error;
    }
    const report = { State: result.State, Result: pathToFileURL(file).href, NativeExecution: 'Use the existing AgentKit host workflow to dispatch/reconcile; editor tasks never invoke native chat tools.' };
    // Never copy Packet, proposals, errors, source bodies or untrusted identifiers to terminal output.
    if (Number.isSafeInteger(result.Revision)) report.Revision = result.Revision;
    if (['fork', 'attach', 'return'].includes(operation)) report.Handoff = 'Open the private Result file for the packet and parent link.';
    if (operation === 'store') report.Memory = 'Stored selections remain candidates; acceptance uses the existing AgentKit memory workflow.';
    return { exitCode: child.status ?? 1, report };
  } catch { return { exitCode: 1, report: { State: 'Failed', Code: 'ConversationTaskUnavailable', Recovery: 'Select an existing private archive, matching request file, and AgentKit installation via AGENTKIT_HOME. Node >=22.18 is required.' } }; }
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const result = run(process.argv.slice(2));
  process.stdout.write(JSON.stringify(result.report) + '\n');
  process.exitCode = result.exitCode;
}
