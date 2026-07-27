import { describe, expect, it, vi } from 'vitest';

import { runCli } from '../src/cli.js';

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
