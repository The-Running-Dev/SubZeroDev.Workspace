import { mkdtempSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { isEntryPoint, runCli } from '../src/cli.js';

describe('CLI', () => {
  it('prints help when no command is supplied', () => {
    const output = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);

    expect(runCli([])).toBe(0);
    expect(output).toHaveBeenCalledWith(
      expect.stringContaining('subzerodev-github <command> [options]'),
    );

    output.mockRestore();
  });

  it('rejects an unknown command', () => {
    const output = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    expect(runCli(['unknown'])).toBe(2);
    expect(output).toHaveBeenCalledWith(expect.stringContaining('Unknown command: unknown'));

    output.mockRestore();
  });
});

describe('entry point detection', () => {
  let directory: string;
  let modulePath: string;

  beforeEach(() => {
    // The temporary directory is resolved because macOS exposes it through a symlink.
    directory = realpathSync(mkdtempSync(join(tmpdir(), 'subzerodev-cli-')));
    modulePath = join(directory, 'cli.js');
    writeFileSync(modulePath, '');
  });

  afterEach(() => {
    rmSync(directory, { recursive: true, force: true });
  });

  it('detects invocation through an installed binary symlink', () => {
    const binary = join(directory, 'subzerodev-github');
    symlinkSync(modulePath, binary);

    expect(isEntryPoint(pathToFileURL(modulePath).href, binary)).toBe(true);
  });

  it('detects direct invocation of the module', () => {
    expect(isEntryPoint(pathToFileURL(modulePath).href, modulePath)).toBe(true);
  });

  it('ignores an unrelated entry point', () => {
    const other = join(directory, 'other.js');
    writeFileSync(other, '');

    expect(isEntryPoint(pathToFileURL(modulePath).href, other)).toBe(false);
  });

  it('ignores a missing or absent entry point', () => {
    expect(isEntryPoint(pathToFileURL(modulePath).href, undefined)).toBe(false);
    expect(isEntryPoint(pathToFileURL(modulePath).href, join(directory, 'gone.js'))).toBe(false);
  });
});
