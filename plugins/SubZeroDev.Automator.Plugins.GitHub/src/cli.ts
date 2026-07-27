#!/usr/bin/env node

import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';

const commandNames = ['sync', 'list', 'stats', 'export', 'validate'] as const;
type CommandName = (typeof commandNames)[number];

const help = `SubZeroDev.Automator.Plugins.GitHub

Usage:
  subzerodev-github <command> [options]

Commands:
  sync      Download or incrementally update repository data
  list      Display repositories
  stats     Display aggregate statistics
  export    Export normalized project data
  validate  Validate configuration and cached data

Options:
  -h, --help     Show help
  -v, --version  Show version
`;

function isCommandName(value: string): value is CommandName {
  return commandNames.some((command) => command === value);
}

export function runCli(argv: readonly string[]): number {
  const { values, positionals } = parseArgs({
    args: [...argv],
    allowPositionals: true,
    strict: true,
    options: {
      help: { type: 'boolean', short: 'h' },
      version: { type: 'boolean', short: 'v' },
    },
  });

  if (values.version) {
    process.stdout.write('0.1.0\n');
    return 0;
  }

  if (values.help || positionals.length === 0) {
    process.stdout.write(help);
    return 0;
  }

  const command = positionals[0];
  if (!command || !isCommandName(command)) {
    const invalidCommand = command ?? '';
    process.stderr.write(`Unknown command: ${invalidCommand}\n\n${help}`);
    return 2;
  }

  process.stderr.write(`Command "${command}" is not implemented yet.\n`);
  return 3;
}

const entryPoint = process.argv[1];
if (entryPoint && import.meta.url === pathToFileURL(entryPoint).href) {
  process.exitCode = runCli(process.argv.slice(2));
}
