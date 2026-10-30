/** Fixture-only AI preference preservation. No profile discovery or services. */
import * as fs from 'node:fs';
import { dirname, basename, join, resolve, relative, isAbsolute, sep } from 'node:path';
import { tmpdir } from 'node:os';
import { createHash, randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import TOML from '@ltd/j-toml';
import { parse as parseJSON, stringify, LosslessNumber, isLosslessNumber } from 'lossless-json';

type ObjectData = Record<string, unknown>;
export type Target = 'claude' | 'codex';
export interface Rule {
  path: string[];
  type: 'string' | 'integer' | 'boolean';
  securityRelevant: boolean;
  sensitivity: 'reviewed-preference';
  min?: number;
  max?: number;
  values?: unknown[];
  pattern?: string;
  maxLength?: number;
}
interface TargetSpec { inspect: string[][]; ignored: { path: string[]; reason: string }[]; owned: Rule[] }
export interface Manifest { version: number; targets: Record<Target, TargetSpec> }
interface Counts { owned: number; ignored: number; inspectionSpaces: number }
type Action = { action: 'unset' } | { action: 'set'; value: unknown };
type Entry = Action & { path: string[] };
interface Snapshot { manifestVersion: number; targets: Record<Target, Entry[]> }
interface Item { target?: Target; path?: string[]; outcome: string; securityRelevant?: boolean }
interface Attention { target?: Target; item?: number; outcome: string; reason?: string }
export interface Result {
  changed: boolean;
  items: Item[];
  attention: Attention[];
  manifestCounts?: Counts;
  coverage?: { inspected: Target[]; notInspected: string[] };
  wouldChange?: boolean;
  error?: string;
}
export class SettingsError extends Error {}
function fail(code: string): never { throw new SettingsError(code); }
const missing = Symbol('missing');
export const targets: Record<Target, string> = { claude: 'settings.json', codex: 'config.toml' };
const targetNames = Object.keys(targets) as Target[];
const deferred = ['claude-desktop', 'chatgpt', 'authored-text', 'skills', 'other-profile-files', 'secrets'];
const scriptDir = dirname(fileURLToPath(import.meta.url));
export const manifestPath = join(scriptDir, 'ai-settings.manifest.json');

function object(value: unknown): value is ObjectData {
  return value !== null && typeof value === 'object' &&
    (Object.getPrototypeOf(value) === Object.prototype || Object.getPrototypeOf(value) === null);
}
function keys(value: ObjectData, required: string[], optional: string[] = []): boolean {
  return required.every(key => Object.hasOwn(value, key)) &&
    Object.keys(value).every(key => required.includes(key) || optional.includes(key));
}
function prefix(a: string[], b: string[]): boolean { return a.every((v, i) => b[i] === v); }
export function semanticEqual(a: unknown, b: unknown): boolean {
  if (Object.is(a, b)) return true;
  if (isLosslessNumber(a) || isLosslessNumber(b)) {
    return isLosslessNumber(a) && isLosslessNumber(b) && a.value === b.value;
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    return Array.isArray(a) && Array.isArray(b) && a.length === b.length &&
      a.every((v, i) => semanticEqual(v, b[i]));
  }
  if (object(a) && object(b)) {
    return Object.keys(a).length === Object.keys(b).length &&
      Object.keys(a).every(key => Object.hasOwn(b, key) && semanticEqual(a[key], b[key]));
  }
  for (const DateType of [TOML.OffsetDateTime, TOML.LocalDateTime, TOML.LocalDate, TOML.LocalTime]) {
    if (a instanceof DateType || b instanceof DateType) {
      return a instanceof DateType && b instanceof DateType &&
        (a as { toISOString(): string }).toISOString() === (b as { toISOString(): string }).toISOString();
    }
  }
  return false;
}
function clone(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(clone);
  if (object(value)) return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, clone(v)]));
  return value; // Parser number/date objects are immutable during planning.
}
function decode(raw: Uint8Array): string {
  try {
    const text = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(raw);
    if (text.startsWith('\uFEFF')) fail('unsupported-encoding');
    return text;
  } catch (error) {
    if (error instanceof SettingsError) throw error;
    fail('unsupported-encoding');
  }
}
export function jsonLoad(raw: string | Uint8Array): unknown {
  const text = typeof raw === 'string' ? raw : decode(raw);
  try {
    // These non-JSON constants were explicitly refused by the previous engine.
    if (/\b(?:NaN|Infinity)\b/.test(text.replace(/"(?:\\.|[^"\\])*"/g, '""'))) fail('invalid-json-number');
    return parseJSON(text, null, {
      parseNumber: literal => {
        const value = Number(literal);
        const integer = /^-?(?:0|[1-9]\d*)$/.test(literal);
        if (!integer && !Number.isFinite(value)) fail('invalid-json-number');
        // Preserve unowned large integers and decimal literals without rounding.
        return integer && Number.isSafeInteger(value) && !Object.is(value, -0)
          ? value : new LosslessNumber(literal);
      },
      onDuplicateKey: () => fail('duplicate-json-key'),
    });
  } catch (error) {
    if (error instanceof SettingsError) throw error;
    fail('malformed-json');
  }
}
export function encode(value: unknown): Buffer {
  return Buffer.from(stringify(value, undefined, 2) + '\n', 'utf8');
}
export function validateValue(value: unknown, rule: Rule): void {
  if (rule.type === 'integer') {
    if (typeof value !== 'number' || !Number.isSafeInteger(value)) fail('invalid-owned-type');
    if (value < rule.min! || value > rule.max!) fail('invalid-owned-range');
  } else if (typeof value !== rule.type) fail('invalid-owned-type');
  if (typeof value === 'string') {
    if (!value || [...value].length > rule.maxLength!) fail('invalid-owned-string');
    if (rule.pattern && !new RegExp('^(?:' + rule.pattern + ')$', 'u').test(value)) fail('invalid-owned-string');
  }
  if (rule.values && !rule.values.some(v => semanticEqual(v, value))) fail('invalid-owned-enum');
}
export function validateManifest(value: unknown): Counts {
  if (!object(value) || !keys(value, ['version', 'targets'])) fail('invalid-manifest');
  if (!Number.isSafeInteger(value.version) || (value.version as number) < 1) fail('invalid-manifest-version');
  if (!object(value.targets) || !keys(value.targets, targetNames)) fail('invalid-manifest-targets');
  const counts = { owned: 0, ignored: 0, inspectionSpaces: 0 };
  for (const target of targetNames) {
    const spec = value.targets[target];
    if (!object(spec) || !keys(spec, ['inspect', 'ignored', 'owned'])) fail('invalid-manifest-target');
    if (!semanticEqual(spec.inspect, [[]])) fail('unsupported-inspection-space');
    counts.inspectionSpaces++;
    if (!Array.isArray(spec.owned) || !spec.owned.length || !Array.isArray(spec.ignored)) fail('invalid-manifest-paths');
    const paths: string[][] = [];
    for (const [owned, entries] of [[false, spec.ignored], [true, spec.owned]] as const) {
      for (const entry of entries) {
        const required = owned ? ['path', 'type', 'securityRelevant', 'sensitivity'] : ['path', 'reason'];
        const optional = owned ? ['min', 'max', 'values', 'pattern', 'maxLength'] : [];
        if (!object(entry) || !keys(entry, required, optional)) fail('invalid-manifest-entry');
        const path = entry.path;
        if (!Array.isArray(path) || !path.length || path.some(p => typeof p !== 'string' || !p)) fail('invalid-manifest-path');
        if (paths.some(p => prefix(p, path) || prefix(path, p))) fail('overlapping-manifest-path');
        paths.push(path);
        if (!owned) {
          if (typeof entry.reason !== 'string' || !entry.reason) fail('invalid-ignore-reason');
          counts.ignored++;
          continue;
        }
        if (target === 'codex' && path.length !== 1) fail('owned-toml-must-be-top-level');
        if (!['string', 'integer', 'boolean'].includes(entry.type as string)) fail('owned-must-be-scalar');
        if (typeof entry.securityRelevant !== 'boolean' || entry.sensitivity !== 'reviewed-preference') fail('invalid-manifest-metadata');
        const has = (name: string) => Object.hasOwn(entry, name);
        if (entry.type === 'integer') {
          if (has('pattern') || has('maxLength') || !Number.isSafeInteger(entry.min) ||
              !Number.isSafeInteger(entry.max) || (entry.min as number) > (entry.max as number)) fail('invalid-integer-rule');
        } else if (has('min') || has('max')) fail('invalid-scalar-rule');
        if (entry.type === 'boolean' && ['values', 'pattern', 'maxLength'].some(has)) fail('invalid-boolean-rule');
        if (entry.type === 'string') {
          if (!Number.isSafeInteger(entry.maxLength) || (entry.maxLength as number) < 1 ||
              (entry.maxLength as number) > 1024 || has('values') === has('pattern')) fail('invalid-string-rule');
          if (has('pattern')) {
            try {
              if (typeof entry.pattern !== 'string') fail('invalid-pattern');
              new RegExp('^(?:' + entry.pattern + ')$', 'u');
            } catch { fail('invalid-pattern'); }
          }
        }
        if (has('values')) {
          if (!Array.isArray(entry.values) || !entry.values.length ||
              entry.values.some((v, i, all) => all.slice(0, i).some(p => semanticEqual(v, p)))) fail('invalid-values-rule');
          const rule = { ...entry };
          delete rule.values;
          for (const item of entry.values) validateValue(item, rule as unknown as Rule);
        }
        counts.owned++;
      }
    }
  }
  return counts;
}
function get(data: unknown, path: string[]): unknown {
  for (const part of path) {
    if (!object(data)) fail('invalid-owned-parent');
    if (!Object.hasOwn(data, part)) return missing;
    data = data[part];
  }
  return data;
}
function setOwn(data: ObjectData, key: string, value: unknown): void {
  Object.defineProperty(data, key, { value, writable: true, enumerable: true, configurable: true });
}
function assign(data: ObjectData, path: string[], action: Action): void {
  let parent = data;
  for (const part of path.slice(0, -1)) {
    if (!Object.hasOwn(parent, part)) {
      if (action.action === 'unset') return;
      setOwn(parent, part, {});
    }
    if (!object(parent[part])) fail('invalid-owned-parent');
    parent = parent[part];
  }
  if (action.action === 'unset') delete parent[path.at(-1)!];
  else setOwn(parent, path.at(-1)!, action.value);
}
function actionFor(data: ObjectData, path: string[]): Action {
  const value = get(data, path);
  return value === missing ? { action: 'unset' } :
    { action: 'set', value: typeof value === 'bigint' ? Number(value) : value };
}
export function* statements(text: string): Generator<[number, number, string]> {
  let start = 0, i = 0, depth = 0;
  let quote: string | undefined;
  while (i < text.length) {
    const char = text[i];
    if (quote) {
      if (quote[0] === '"' && char === '\\') { i += 2; continue; }
      if (text.startsWith(quote, i)) {
        i += quote.length;
        if (quote.length === 3) while (text[i] === quote[0]) i++;
        quote = undefined;
        continue;
      }
    } else if ('"\''.includes(char)) {
      quote = text.startsWith(char.repeat(3), i) ? char.repeat(3) : char;
      i += quote.length;
      continue;
    } else if (char === '#') {
      const end = text.indexOf('\n', i);
      i = end < 0 ? text.length : end;
      continue;
    } else if ('[{'.includes(char)) depth++;
    else if (']}'.includes(char)) depth--;
    else if (char === '\n' && depth === 0) {
      yield [start, i + 1, text.slice(start, i + 1)];
      start = i + 1;
    }
    i++;
  }
  if (start < text.length) yield [start, text.length, text.slice(start)];
}
function outsideIndex(text: string, wanted: string): number {
  let quote: string | undefined;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (quote) {
      if (quote === '"' && char === '\\') { i++; continue; }
      if (char === quote) quote = undefined;
    } else if ('"\''.includes(char)) quote = char;
    else if (char === wanted) return i;
  }
  return -1;
}
export function tomlLoad(text: string): ObjectData {
  try {
    // Explicit TOML 1.0, no extensions. BigInts distinguish integers from floats.
    const data = TOML.parse[1.0](text, { joiner: '\n', bigint: true });
    function normalize(value: unknown): unknown {
      if (Array.isArray(value)) return value.map(normalize);
      if (value === null || typeof value !== 'object' ||
          [TOML.OffsetDateTime, TOML.LocalDateTime, TOML.LocalDate, TOML.LocalTime].some(Type => value instanceof Type)) return value;
      // The parser's tables use a private prototype; expose only their own data.
      return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, normalize(item)]));
    }
    return normalize(data) as ObjectData;
  } catch { fail('malformed-toml'); }
}
type Span = [number, number, number, number];
function tomlSpans(text: string, rules: Rule[]): { spans: Map<string, Span>; end: number } {
  const names = new Set(rules.map(r => r.path[0]));
  const spans = new Map<string, Span>();
  let end = text.length, lastEnd = 0;
  for (const [start, finish, statement] of statements(text)) {
    const trimmed = statement.trimStart();
    if (!trimmed || trimmed.startsWith('#')) continue;
    if (trimmed.startsWith('[')) { end = lastEnd; break; }
    lastEnd = finish;
    const equals = outsideIndex(statement, '=');
    if (equals < 0) fail('unsupported-toml-statement');
    const probe = tomlLoad(statement.slice(0, equals) + '=0');
    const key = Object.keys(probe)[0];
    if (!names.has(key)) continue;
    const body = statement.replace(/[\r\n]+$/, '');
    if (object(probe[key]) || /[\r\n]/.test(body)) fail('unsupported-owned-toml-form');
    let valueStart = equals + 1;
    while (valueStart < body.length && ' \t'.includes(statement[valueStart])) valueStart++;
    const comment = outsideIndex(body.slice(valueStart), '#');
    let valueEnd = comment < 0 ? body.length : valueStart + comment;
    while (valueEnd > valueStart && ' \t'.includes(statement[valueEnd - 1])) valueEnd--;
    if (['"""', "'''"].includes(statement.slice(valueStart, valueStart + 3))) fail('unsupported-owned-toml-form');
    spans.set(key, [start, finish, start + valueStart, start + valueEnd]);
  }
  return { spans, end };
}
export function parse(raw: Buffer, target: Target, rules: Rule[]): { text: string; data: ObjectData } {
  const text = decode(raw);
  let data: ObjectData;
  if (target === 'claude') {
    const parsed = jsonLoad(text);
    if (!object(parsed)) fail('json-root-must-be-object');
    data = parsed;
  } else {
    data = tomlLoad(text);
    const { spans } = tomlSpans(text, rules);
    for (const rule of rules) {
      if (Object.hasOwn(data, rule.path[0]) && !spans.has(rule.path[0])) fail('unsupported-owned-toml-form');
    }
  }
  for (const rule of rules) {
    const value = get(data, rule.path);
    if (value === missing) continue;
    if (target === 'codex' && rule.type === 'integer' && typeof value !== 'bigint') fail('invalid-owned-type');
    validateValue(typeof value === 'bigint' ? Number(value) : value, rule);
  }
  return { text, data };
}
export function plan(raw: Buffer, target: Target, rules: Rule[], actions: Action[]): { output: Buffer; changes: Rule[] } {
  let { text, data } = parse(raw, target, rules);
  const desired = clone(data) as ObjectData;
  const changes: Rule[] = [];
  rules.forEach((rule, i) => {
    const action = actions[i];
    if (!semanticEqual(actionFor(data, rule.path), action)) changes.push(rule);
    const desiredAction: Action = target === 'codex' && rule.type === 'integer' && action.action === 'set'
      ? { action: 'set', value: BigInt(action.value as number) } : action;
    assign(desired, rule.path, desiredAction);
  });
  if (!changes.length) return { output: raw, changes };
  let output: Buffer;
  if (target === 'claude') output = encode(desired);
  else {
    const { spans, end } = tomlSpans(text, rules);
    const edits: [number, number, string][] = [], additions: string[] = [];
    const newline = text.includes('\r\n') ? '\r\n' : '\n';
    rules.forEach((rule, i) => {
      if (!changes.includes(rule)) return;
      const action = actions[i], key = rule.path[0], span = spans.get(key);
      if (action.action === 'unset') {
        if (span) edits.push([span[0], span[1], '']);
      } else {
        const literal = JSON.stringify(action.value);
        if (span) edits.push([span[2], span[3], literal]);
        else additions.push(JSON.stringify(key) + ' = ' + literal + newline);
      }
    });
    if (additions.length) edits.push([end, end, (end && text[end - 1] !== '\n' ? newline : '') + additions.join('')]);
    edits.sort((a, b) => b[0] - a[0] || b[1] - a[1]);
    for (const [start, finish, replacement] of edits) text = text.slice(0, start) + replacement + text.slice(finish);
    output = Buffer.from(text, 'utf8');
  }
  if (!semanticEqual(parse(output, target, rules).data, desired)) fail('semantic-verification-failed');
  return { output, changes };
}

export interface IO {
  stat(path: string): { size: bigint; mtimeNs: bigint };
  read(path: string): Buffer;
  replace(path: string, raw: Buffer): void;
}
export const systemIO: IO = {
  stat: path => fs.statSync(path, { bigint: true }),
  read: path => fs.readFileSync(path),
  replace: (path, raw) => replace(path, raw),
};
function codeIs(error: unknown, codes: string[]): boolean {
  return error instanceof Error && 'code' in error && codes.includes(String(error.code));
}
function transient(error: unknown): boolean { return codeIs(error, ['EACCES', 'EPERM', 'EBUSY', 'ETXTBSY']); }
export function fingerprint(path: string, io: IO = systemIO): { observed: string | null; raw: Buffer | null } {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const before = io.stat(path), raw = io.read(path), after = io.stat(path);
      if (before.size === after.size && before.mtimeNs === after.mtimeNs) {
        return { observed: String(after.size) + ':' + String(after.mtimeNs) + ':' +
          createHash('sha256').update(raw).digest('hex'), raw };
      }
    } catch (error) {
      if (codeIs(error, ['ENOENT'])) return { observed: null, raw: null };
      if (!transient(error) || attempt === 2) throw error;
    }
  }
  fail('concurrent-modification');
}
function windowsPermissions(mode: 'PrivateDirectory' | 'CopyDacl', path: string, source?: string): void {
  const result = spawnSync(process.env.AI_SETTINGS_PWSH || 'pwsh',
    ['-NoProfile', '-NonInteractive', '-File', join(scriptDir, 'Set-AISettingsPermissions.ps1'), '-Mode', mode],
    { env: { ...process.env, AI_SETTINGS_ACL_PATH: path, AI_SETTINGS_ACL_SOURCE: source || '' },
      encoding: 'utf8', windowsHide: true, timeout: 30000 });
  if (result.error || result.status !== 0) fail(mode === 'PrivateDirectory' ? 'backup-permissions-failed' : 'target-permissions-failed');
}
export function privateDir(path: string): void {
  fs.mkdirSync(path, { recursive: true, mode: 0o700 });
  if (process.platform === 'win32') windowsPermissions('PrivateDirectory', path);
  else fs.chmodSync(path, 0o700);
}
export function copyWindowsDacl(source: string, destination: string): void {
  windowsPermissions('CopyDacl', destination, source);
}
export function replace(path: string, raw: Buffer, copyDacl = copyWindowsDacl): void {
  const temporary = join(dirname(path), '.ai-settings-' + randomUUID());
  const descriptor = fs.openSync(temporary, 'wx', 0o600);
  let open = true;
  try {
    // No private content reaches the staging file until permissions are ready.
    let original: fs.Stats | undefined;
    try { original = fs.statSync(path); } catch (error) { if (!codeIs(error, ['ENOENT'])) throw error; }
    if (original) {
      if (process.platform === 'win32') copyDacl(path, temporary);
      else fs.fchmodSync(descriptor, original.mode & 0o7777);
    }
    fs.writeFileSync(descriptor, raw);
    fs.fsyncSync(descriptor);
    fs.closeSync(descriptor);
    open = false;
    fs.renameSync(temporary, path);
  } finally {
    if (open) fs.closeSync(descriptor);
    fs.rmSync(temporary, { force: true });
  }
}
function within(path: string, parent: string): boolean {
  const part = relative(parent, path);
  return part !== '' && part !== '..' && !part.startsWith('..' + sep) && !isAbsolute(part);
}
function samePath(a: string, b: string): boolean { return relative(a, b) === ''; }
function realExisting(path: string): string {
  try { return fs.realpathSync.native(path); } catch (error) {
    if (!codeIs(error, ['ENOENT'])) throw error;
    const parent = dirname(path);
    if (parent === path) throw error;
    return join(realExisting(parent), basename(path));
  }
}
function tempAbsolute(path: string): string {
  const absolute = resolve(path), alias = resolve(tmpdir());
  return samePath(absolute, alias) || within(absolute, alias) ?
    resolve(fs.realpathSync.native(alias), relative(alias, absolute)) : absolute;
}
export interface ManagerOptions {
  claudeHome?: string;
  codexHome?: string;
  dataPath?: string;
  backupRoot?: string;
  codexRunning?: () => boolean;
  hook?: (event: string, attempt: number, path: string) => void;
  io?: Partial<IO>;
}
export class Manager {
  manifest: Manifest;
  counts: Counts;
  root: string;
  targets: Record<Target, string>;
  data: string;
  backups: string;
  result: Result;
  io: IO;
  hook: NonNullable<ManagerOptions['hook']>;
  codexRunning: () => boolean;
  constructor(sandbox: string, manifest: unknown, options: ManagerOptions = {}) {
    this.counts = validateManifest(manifest);
    this.manifest = manifest as Manifest;
    const requested = tempAbsolute(sandbox), temp = fs.realpathSync.native(tmpdir());
    this.root = realExisting(requested);
    if (!within(this.root, temp) || !samePath(this.root, requested) || !fs.statSync(this.root).isDirectory()) {
      fail('sandbox-must-be-existing-temp-child');
    }
    this.targets = {
      claude: join(this.bound(options.claudeHome || join(this.root, 'claude')), targets.claude),
      codex: join(this.bound(options.codexHome || join(this.root, 'codex')), targets.codex),
    };
    this.data = this.bound(options.dataPath || join(this.root, 'repo', 'preferences.json'));
    this.backups = this.bound(options.backupRoot || join(this.root, 'private-backups'));
    const paths = [...Object.values(this.targets).map(p => dirname(p)), this.data, this.backups];
    if (paths.some((a, i) => paths.slice(i + 1).some(b => samePath(a, b) || within(a, b) || within(b, a)))) {
      fail('overlapping-sandbox-paths');
    }
    if (samePath(this.backups, dirname(this.data)) || within(this.backups, dirname(this.data))) {
      fail('backups-must-be-outside-data-repository');
    }
    this.io = { ...systemIO, ...options.io };
    this.hook = options.hook || (() => {});
    this.codexRunning = options.codexRunning || (() => false);
    this.result = { changed: false, items: [], attention: [], manifestCounts: this.counts,
      coverage: { inspected: targetNames, notInspected: deferred } };
  }
  bound(path: string): string {
    path = tempAbsolute(path);
    if (!within(path, this.root) || !samePath(realExisting(path), path)) fail('path-outside-sandbox-or-linked');
    // lstat rejects symlinks and junctions even when their target is inside the sandbox.
    for (let part = path; !samePath(part, dirname(this.root)); part = dirname(part)) {
      try { if (fs.lstatSync(part).isSymbolicLink()) fail('path-outside-sandbox-or-linked'); }
      catch (error) { if (!codeIs(error, ['ENOENT'])) throw error; }
    }
    return path;
  }
  readTarget(target: Target): { observed: string; raw: Buffer; text: string; data: ObjectData } {
    const { observed, raw } = fingerprint(this.bound(this.targets[target]), this.io);
    if (raw === null || observed === null) fail('missing-target');
    return { observed, raw, ...parse(raw, target, this.manifest.targets[target].owned) };
  }
  snapshot(): Snapshot {
    const { raw } = fingerprint(this.bound(this.data), this.io);
    if (raw === null) fail('missing-snapshot');
    const data = jsonLoad(raw);
    if (!object(data) || !keys(data, ['manifestVersion', 'targets']) ||
        !Number.isSafeInteger(data.manifestVersion) || data.manifestVersion !== this.manifest.version) fail('snapshot-version-or-shape');
    if (!object(data.targets) || !keys(data.targets, targetNames)) fail('incomplete-snapshot');
    for (const target of targetNames) {
      const entries = data.targets[target], rules = this.manifest.targets[target].owned;
      if (!Array.isArray(entries) || entries.length !== rules.length) fail('incomplete-snapshot');
      rules.forEach((rule, i) => {
        const entry = entries[i];
        if (!object(entry) || !semanticEqual(entry.path, rule.path)) fail('incomplete-snapshot');
        if (entry.action === 'set' && keys(entry, ['path', 'action', 'value'])) validateValue(entry.value, rule);
        else if (entry.action !== 'unset' || !keys(entry, ['path', 'action'])) fail('invalid-snapshot-action');
      });
    }
    return data as unknown as Snapshot;
  }
  classify(target: Target, data: ObjectData, snapshot?: Entry[]): void {
    const spec = this.manifest.targets[target];
    let ordinal = 0;
    const walk = (value: unknown, path: string[] = []) => {
      if (spec.ignored.some(e => semanticEqual(e.path, path))) {
        this.result.items.push({ target, path, outcome: 'ignored' });
      } else if (spec.owned.some(r => semanticEqual(r.path, path))) return;
      else if (object(value) && Object.keys(value).length) {
        for (const [key, child] of Object.entries(value)) walk(child, [...path, key]);
      } else if (object(value) && spec.owned.some(r => prefix(path, r.path))) return;
      else if (path.length) {
        ordinal++;
        const suspect = path.some(key => /token|secret|password|credential|api.?key|auth/i.test(key));
        this.result.attention.push({ target, item: ordinal, outcome: suspect ? 'suspected-secret' : 'unclassified' });
      }
    };
    walk(data);
    spec.owned.forEach((rule, index) => {
      const entry = snapshot?.[index];
      const outcome = !entry ? 'owned' : semanticEqual(actionFor(data, rule.path),
        entry.action === 'set' ? { action: 'set', value: entry.value } : { action: 'unset' }) ? 'in-sync' : 'drift';
      this.result.items.push({ target, path: rule.path, outcome, securityRelevant: rule.securityRelevant });
    });
  }
  capture(): Result {
    const captured: Snapshot = { manifestVersion: this.manifest.version, targets: { claude: [], codex: [] } };
    const sources: [Target, string][] = [];
    for (const target of targetNames) {
      const { observed, data } = this.readTarget(target);
      sources.push([target, observed]);
      this.classify(target, data);
      captured.targets[target] = this.manifest.targets[target].owned.map(rule => ({ path: rule.path, ...actionFor(data, rule.path) }));
    }
    const output = encode(captured);
    for (let attempt = 0; attempt < 3; attempt++) {
      const { observed, raw: previous } = fingerprint(this.bound(this.data), this.io);
      if (previous?.equals(output)) return this.result;
      for (const [target, source] of sources) {
        if (fingerprint(this.bound(this.targets[target]), this.io).observed !== source) fail('concurrent-modification');
      }
      this.hook('capture-before-check', attempt, this.data);
      if (fingerprint(this.bound(this.data), this.io).observed !== observed) continue;
      fs.mkdirSync(dirname(this.data), { recursive: true });
      this.io.replace(this.data, output);
      this.result.changed = true;
      if (!fingerprint(this.bound(this.data), this.io).raw?.equals(output)) fail('overwritten-after-write');
      return this.result;
    }
    fail('concurrent-modification');
  }
  status(): Result {
    let snapshot: Snapshot | undefined;
    try { snapshot = this.snapshot(); }
    catch { this.result.attention.push({ outcome: 'snapshot-unavailable' }); }
    for (const target of targetNames) {
      try { this.classify(target, this.readTarget(target).data, snapshot?.targets[target]); }
      catch (error) {
        this.result.attention.push({ target, outcome: 'unavailable', reason: error instanceof SettingsError ? error.message : 'io-error' });
      }
    }
    return this.result;
  }
  restore(whatIf = false, force = false): Result {
    if (this.codexRunning() && !force) fail('codex-running');
    const snapshot = this.snapshot();
    const planned: { target: Target; actions: Action[]; changed: boolean }[] = [];
    // Complete preflight before creating any backups or changing targets.
    for (const target of targetNames) {
      const { raw, data } = this.readTarget(target), rules = this.manifest.targets[target].owned;
      const actions = snapshot.targets[target].map((entry): Action => entry.action === 'set' ?
        { action: 'set', value: entry.value } : { action: 'unset' });
      const { output, changes } = plan(raw, target, rules, actions);
      this.classify(target, data, snapshot.targets[target]);
      planned.push({ target, actions, changed: !output.equals(raw) });
      for (const rule of changes) {
        this.result.items.push({ target, path: rule.path, outcome: 'would-change', securityRelevant: rule.securityRelevant });
      }
    }
    if (whatIf) { this.result.wouldChange = planned.some(p => p.changed); return this.result; }
    const applied: { path: string; raw: Buffer; written: string | null; item: Item }[] = [];
    let run: string | undefined;
    try {
      for (const { target, actions } of planned) {
        const path = this.targets[target];
        let completed = false;
        for (let attempt = 0; attempt < 3; attempt++) {
          const { observed, raw } = this.readTarget(target);
          const { output, changes } = plan(raw, target, this.manifest.targets[target].owned, actions);
          if (!changes.length) {
            this.result.items.push({ target, outcome: 'unchanged' });
            completed = true;
            break;
          }
          this.hook('before-check', attempt, path);
          if (fingerprint(this.bound(path), this.io).observed !== observed) continue;
          if (!run) {
            privateDir(this.bound(this.backups));
            run = join(this.backups, randomUUID());
            privateDir(this.bound(run));
          }
          fs.writeFileSync(this.bound(join(run, targets[target])), raw, { mode: 0o600 });
          if (fingerprint(this.bound(path), this.io).observed !== observed) continue;
          this.hook('after-check', attempt, path);
          try { this.io.replace(this.bound(path), output); }
          catch (error) {
            if (!transient(error)) throw error;
            if (attempt < 2) continue;
            fail('replace-failed');
          }
          const item: Item = { target, outcome: 'applied' };
          const entry = { path, raw, written: null as string | null, item };
          applied.push(entry);
          this.result.items.push(item);
          this.result.changed = true;
          const { observed: written, raw: current } = fingerprint(this.bound(path), this.io);
          entry.written = current?.equals(output) ? written : null;
          this.hook('after-write', attempt, path);
          if (fingerprint(this.bound(path), this.io).observed !== written || !current?.equals(output)) fail('overwritten-after-write');
          completed = true;
          break;
        }
        if (!completed) fail('concurrent-modification');
      }
      if (run) {
        fs.writeFileSync(this.bound(join(run, 'complete.json')), encode({ completed: true }), { mode: 0o600 });
        try { this.prune(); } catch { this.result.attention.push({ outcome: 'backup-retention-failed' }); }
      }
      return this.result;
    } catch (error) {
      for (const entry of applied.reverse()) {
        try {
          this.hook('before-rollback', 0, entry.path);
          if (!entry.written || fingerprint(this.bound(entry.path), this.io).observed !== entry.written) {
            entry.item.outcome = 'rollback-conflict';
            continue;
          }
          this.io.replace(this.bound(entry.path), entry.raw);
          entry.item.outcome = fingerprint(this.bound(entry.path), this.io).raw?.equals(entry.raw) ? 'rolled-back' : 'rollback-conflict';
        } catch { entry.item.outcome = 'rollback-failed'; }
      }
      throw error; // Failed runs remain for explicit investigation.
    }
  }
  prune(): void {
    const completed = fs.readdirSync(this.bound(this.backups))
      .map(name => this.bound(join(this.backups, name)))
      .filter(path => fs.statSync(path).isDirectory() && fs.existsSync(this.bound(join(path, 'complete.json'))))
      .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
    for (const path of completed.slice(5)) {
      const names = fs.readdirSync(path);
      if (!names.every(name => [...Object.values(targets), 'complete.json'].includes(name))) continue;
      // Never recursively follow arbitrary paths while applying retention.
      for (const name of names) fs.unlinkSync(this.bound(join(path, name)));
      fs.rmdirSync(path);
    }
  }
}
export function main(args: string[]): { result: Result; exitCode: number } {
  let manager: Manager | undefined;
  let result: Result = { changed: false, items: [], attention: [] };
  try {
    const [major, minor] = process.versions.node.split('.').map(Number);
    if (major < 22 || major === 22 && minor < 18) fail('node-22.18-or-later-required');
    const { values, positionals } = parseArgs({ args, allowPositionals: true, options: {
      'sandbox-root': { type: 'string' }, manifest: { type: 'string', default: manifestPath },
      'claude-home': { type: 'string' }, 'codex-home': { type: 'string' },
      'data-path': { type: 'string' }, 'backup-root': { type: 'string' },
      'codex-running': { type: 'boolean' }, 'what-if': { type: 'boolean' },
      force: { type: 'boolean' }, 'fail-on-attention': { type: 'boolean' },
    } });
    const command = positionals[0];
    if (positionals.length !== 1 || !['capture', 'status', 'restore'].includes(command) || !values['sandbox-root']) fail('invalid-arguments');
    if (values['what-if'] && command !== 'restore') fail('what-if-requires-restore');
    manager = new Manager(values['sandbox-root'], jsonLoad(fs.readFileSync(values.manifest)), {
      claudeHome: values['claude-home'], codexHome: values['codex-home'],
      dataPath: values['data-path'], backupRoot: values['backup-root'], codexRunning: () => !!values['codex-running'],
    });
    result = command === 'restore' ? manager.restore(values['what-if'], values.force) :
      command === 'capture' ? manager.capture() : manager.status();
    return { result, exitCode: values['fail-on-attention'] && result.attention.length ? 2 : 0 };
  } catch (error) {
    result = manager?.result || result;
    result.error = error instanceof SettingsError ? error.message : 'io-or-internal-error';
    return { result, exitCode: 1 };
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const { result, exitCode } = main(process.argv.slice(2));
  process.stdout.write(JSON.stringify(result) + '\n');
  process.exitCode = exitCode;
}
