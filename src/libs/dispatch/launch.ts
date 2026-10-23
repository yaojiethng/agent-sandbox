// The argv for one assignment, and the shell command string a launch site
// prints.
//
// The command string is the seam's contract with its callers: a launch site
// substitutes it for its own inline `pi --provider ... -p` line, so the runtime
// is chosen in one place. The brief is read at run time with `$(cat <path>)`,
// so the printed command carries a path and never the brief text.

import { accessSync, constants, readFileSync, statSync } from 'node:fs';
import { basename } from 'node:path';
import type { Assignment } from './table.ts';

export type LaunchOptions = { brief: string; dir: string; session?: string };

export function argvFor(a: Assignment, o: LaunchOptions): string[] {
  // The command string reads the brief with `$(cat <path>)`, and a substitution
  // drops the trailing newlines, so the argv carries the same text.
  const brief = readFileSync(o.brief, 'utf8').replace(/\n+$/, '');
  if (a.runtime === 'opencode') {
    return [opencodeBin(), ...opencodeWords(a, o), brief];
  }
  return ['pi', ...piWords(a, o), '-p', brief];
}

export function commandFor(a: Assignment, o: LaunchOptions): string {
  const brief = `"$(cat ${quote(o.brief)})"`;
  if (a.runtime === 'opencode') {
    // The binary stands unquoted, exactly as the shell seam interpolates it.
    return `${opencodeBin()} ${opencodeWords(a, o).map(quote).join(' ')} ${brief}`;
  }
  return `${['pi', ...piWords(a, o), '-p'].map(quote).join(' ')} ${brief}`;
}

function opencodeWords(a: Assignment, o: LaunchOptions): string[] {
  // The CLI's error channel is stderr at ERROR level. Without these flags a
  // refused request prints only its banner, and the process stays alive on an
  // event subscription it never closes, so a caller cannot tell a refusal from
  // a slow run.
  const words = [
    'run',
    '--auto',
    '--print-logs',
    '--log-level',
    'ERROR',
    '--title',
    basename(o.brief),
    '--dir',
    o.dir,
    '-m',
    a.key,
  ];
  if (a.level !== undefined) words.push('--variant', a.level);
  if (o.session) words.push('--session', o.session);
  return words;
}

function piWords(a: Assignment, o: LaunchOptions): string[] {
  const words = ['--provider', a.provider, '--model', a.model];
  if (a.level !== undefined) words.push('--thinking', a.level);
  if (o.session) words.push('--session', o.session);
  return words;
}

export function opencodeBin(): string {
  const declared = process.env.DISPATCH_OPENCODE_BIN;
  if (declared) return declared;
  const found = onPath('opencode');
  if (found) return found;
  // The agent-home install, for a session whose image predates the global one.
  return `${process.env.AGENT_HOME || `${process.env.HOME ?? ''}/.pi`}/opencode/node_modules/.bin/opencode`;
}

// Whether a binary would answer `command -v`: a name is looked for on PATH, and
// a path is asked whether it holds an executable file.
export function binaryRuns(bin: string): boolean {
  if (!bin.includes('/')) return onPath(bin) !== undefined;
  try {
    if (!statSync(bin).isFile()) return false;
    accessSync(bin, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function onPath(name: string): string | undefined {
  for (const dir of (process.env.PATH ?? '').split(':')) {
    if (dir === '') continue;
    const candidate = `${dir}/${name}`;
    try {
      if (!statSync(candidate).isFile()) continue;
      accessSync(candidate, constants.X_OK);
      return candidate;
    } catch {
      // Not here, or not executable, so the search continues.
    }
  }
  return undefined;
}

// The characters `printf %q` leaves bare in the middle of a word, plus the two
// it quotes only as the first character (`#` would start a comment, `~` a home
// expansion). Everything else is escaped, so the word re-reads as one word.
const BARE = new Set([...'#%+-./0123456789:=@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~']);
const LEADING = new Set(['#', '~']);

const NAMED_ESCAPE: Record<number, string> = {
  0x07: '\\a',
  0x08: '\\b',
  0x09: '\\t',
  0x0a: '\\n',
  0x0b: '\\v',
  0x0c: '\\f',
  0x0d: '\\r',
  0x1b: '\\E',
  0x27: "\\'",
  0x5c: '\\\\',
};

function quote(word: string): string {
  if (word === '') return "''";
  const bytes = Buffer.from(word, 'utf8');
  // A byte outside printable ASCII cannot be escaped with a backslash, so the
  // whole word switches to the `$'...'` form. The octal form is byte-exact, so
  // it reads back as the same string in any locale.
  const printable = [...bytes].every((b) => b >= 0x20 && b < 0x7f);
  if (!printable) {
    const body = [...bytes]
      .map((b) => {
        const named = NAMED_ESCAPE[b];
        if (named !== undefined) return named;
        if (b >= 0x20 && b < 0x7f) return String.fromCharCode(b);
        return `\\${b.toString(8).padStart(3, '0')}`;
      })
      .join('');
    return `$'${body}'`;
  }
  const body = [...bytes]
    .map((b, i) => {
      const char = String.fromCharCode(b);
      if (!BARE.has(char) || (i === 0 && LEADING.has(char))) return `\\${char}`;
      return char;
    })
    .join('');
  return body;
}
