#!/usr/bin/env node
// The command line of the dispatch library, called by scripts/dispatch.sh.
//
// It answers the role table's questions (a role's ordered entries, the
// assignment in force, the runtime that reaches an assignment, whether a role
// can run here), it holds the route machine and the session memory, and it
// resolves one attempt into the argv of its runtime.
//
// Exit codes: 0 run, 2 usage, 3 blocked, 4 unroutable.

import { readFileSync } from 'node:fs';
import { classify } from './classify.ts';
import { binaryRuns, commandFor, opencodeBin } from './launch.ts';
import { CLASSES, REASONS, SCOPES, applyClock } from './machine.ts';
import { decodeSeatState, resolveAttempts, seatOrders, seatTurn, startSeats } from './seats.ts';
import type { SeatOrder, SeatState } from './seats.ts';
import { defaultPath, load, readJson, recordAttempt, recordOutcomes, writeJson } from './state.ts';
import { DispatchError, UsageError } from './errors.ts';
import { decodeLevel, defaultTableFile, firstAssignment, parseAssignment, pinned, roleAssignments, tableAssignments } from './table.ts';
import type { Assignment } from './table.ts';
import type { Refusal } from './types.ts';
import { decideWalk } from './walk.ts';

// What a command accepts: a value consumes the token after it, whatever it
// looks like; a switch consumes nothing; a list may repeat. Any flag outside the
// declaration is refused, so a misspelled option cannot silently become a
// default.
type Spec = { values?: string[]; switches?: string[]; lists?: string[] };

function now(): number {
  return Number(process.env.DISPATCH_NOW ?? Date.now());
}

/** The table's own path: the caller's override, or the environment's choice. */
function tablePath(map: Map<string, string[]>): string {
  return one(map, '--file') ?? defaultTableFile();
}

function session(): string {
  return process.env.SESSION_ID || 'default';
}

function parse(argv: string[], spec: Spec): Map<string, string[]> {
  const values = new Set(spec.values ?? []);
  const switches = new Set(spec.switches ?? []);
  const lists = new Set(spec.lists ?? []);
  const out = new Map<string, string[]>();
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith('--')) throw new UsageError(`dispatch: unexpected argument: ${key}`);
    if (switches.has(key)) {
      out.set(key, ['']);
      continue;
    }
    if (!values.has(key) && !lists.has(key)) throw new UsageError(`dispatch: unknown option: ${key}`);
    const value = argv[i + 1];
    if (value === undefined) throw new UsageError(`dispatch: ${key} needs a value`);
    i += 1;
    const list = out.get(key) ?? [];
    list.push(value);
    out.set(key, list);
  }
  return out;
}

function one(map: Map<string, string[]>, key: string): string | undefined {
  return map.get(key)?.at(-1);
}

function iso(ms: number): string {
  return new Date(ms).toISOString();
}

function decodeEnum<T extends string>(value: string, allowed: T[], flag: string): T {
  if (!(allowed as string[]).includes(value)) {
    throw new UsageError(`dispatch: ${flag} '${value}' is not one of ${allowed.join(', ')}`);
  }
  return value as T;
}

function decodeInt(value: string, flag: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) throw new UsageError(`dispatch: ${flag} '${value}' is not an integer`);
  return parsed;
}

function decodeNumber(value: string | undefined, flag: string): number | undefined {
  if (value === undefined) return undefined;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) throw new UsageError(`dispatch: ${flag} '${value}' is not a number`);
  return parsed;
}

/** A flag every command form needs: its absence names the flag, not the value. */
function required(map: Map<string, string[]>, flag: string): string {
  const value = one(map, flag);
  if (value === undefined || value === '') throw new UsageError(`dispatch: ${flag} is required`);
  return value;
}

function refusing<T>(run: () => T): T {
  try {
    return run();
  } catch (error) {
    if (error instanceof DispatchError) {
      process.stderr.write(`${error.message}\n`);
      process.exit(error.code);
    }
    throw error;
  }
}

function cmdRecord(argv: string[]): never {
  const map = parse(argv, {
    values: ['--route', '--class', '--scope', '--reason', '--at', '--refresh-at'],
    switches: ['--metered'],
  });
  const route = required(map, '--route');
  const klass = required(map, '--class');
  const reason = one(map, '--reason');
  const outcome = {
    at: decodeNumber(one(map, '--at'), '--at') ?? now(),
    class: decodeEnum(klass, CLASSES, '--class'),
    scope: decodeEnum(one(map, '--scope') ?? 'none', SCOPES, '--scope'),
    reason: reason === undefined ? undefined : decodeEnum(reason, REASONS, '--reason'),
    refreshAt: decodeNumber(one(map, '--refresh-at'), '--refresh-at'),
  };
  const next = recordAttempt(defaultPath(), session(), route, outcome, map.has('--metered'));
  process.stdout.write(`${JSON.stringify(next)}\n`);
  process.exit(0);
}

function cmdClassify(argv: string[]): never {
  const map = parse(argv, { values: ['--text', '--at'] });
  const text = one(map, '--text') ?? '';
  const verdict = classify(text, decodeNumber(one(map, '--at'), '--at') ?? now());
  process.stdout.write(`${verdict.id} ${verdict.class} ${verdict.scope} ${verdict.reason ?? '-'} ${verdict.refreshAt ?? '-'}\n`);
  process.exit(0);
}

/** The first line of a text the classifier reads as a refusal, or nothing. */
function cmdRefusal(argv: string[]): never {
  const map = parse(argv, { values: ['--text'] });
  const at = now();
  for (const line of (one(map, '--text') ?? '').split('\n')) {
    if (line.trim() === '') continue;
    if (classify(line, at).class === 'unknown') continue;
    process.stdout.write(line);
    process.exit(0);
  }
  process.exit(1);
}

function cmdStatus(argv: string[]): never {
  const map = parse(argv, { switches: ['--json'] });
  const state = load(defaultPath(), session());
  if (map.has('--json')) {
    process.stdout.write(`${JSON.stringify(state, null, 2)}\n`);
    process.exit(0);
  }
  const at = now();
  const routes = Object.keys(state.routes).sort();
  if (routes.length === 0) {
    process.stdout.write('no route has been attempted this session\n');
    process.exit(0);
  }
  for (const route of routes) {
    const record = applyClock(state.routes[route], at);
    const usage = state.usage[route] ?? 0;
    if (record.state === 'cooling') {
      process.stdout.write(`${route} cooling until ${iso(record.until)} (${record.reason}) used ${usage}\n`);
    } else {
      process.stdout.write(`${route} ${record.state} used ${usage}\n`);
    }
  }
  process.exit(0);
}

// Whether a role can run in this session: the first assignment whose runtime is
// present wins, so a role whose free entry is unrunnable still runs on its paid
// fallback. The message names the last runtime that was missing, which is what a
// caller reads when no entry can run.
function checkRole(role: string, path: string): never {
  let last = '';
  for (const assignment of roleAssignments(role, path)) {
    if (assignment.runtime === 'pi') {
      if (binaryRuns('pi')) process.exit(0);
      last = `dispatch: role '${role}' needs the pi CLI, not on PATH`;
      continue;
    }
    const bin = opencodeBin();
    if (binaryRuns(bin)) process.exit(0);
    last = `dispatch: role '${role}' needs the opencode CLI, not runnable: ${bin}`;
  }
  throw new DispatchError(last);
}

// resolveOne ROLE FILE ENTRY PIN  --  the assignment a caller will attempt.
//
// Nothing given resolves the role's head. An entry is a value from the role's
// own line, so its refusal is the table's. A pin is the caller's override, so a
// pin that is not `provider/model` says so about the pin.
function resolveOne(role: string, path: string, entry?: string, pin?: string): Assignment {
  if (pin !== undefined) return pinned(role, pin);
  return entry === undefined ? firstAssignment(role, path) : parseAssignment(role, entry);
}

function cmdTable(argv: string[]): never {
  const [sub, ...rest] = argv;
  if (sub === 'list') {
    const map = parse(rest, { values: ['--role', '--file'] });
    const list = roleAssignments(required(map, '--role'), tablePath(map)).map((a) => a.text).join('\n');
    process.stdout.write(`${list}\n`);
    process.exit(0);
  }
  if (sub === 'resolve') {
    const map = parse(rest, { values: ['--role', '--file', '--entry', '--pin'] });
    // An entry given outright is resolved as written, so a caller holding a
    // fallback or a pin asks about the assignment it will attempt rather than
    // about the role's head.
    const resolved = resolveOne(required(map, '--role'), tablePath(map), one(map, '--entry'), one(map, '--pin'));
    process.stdout.write(`${resolved.key} ${resolved.level ?? '-'} ${resolved.runtime}\n`);
    process.exit(0);
  }
  if (sub === 'check') {
    const map = parse(rest, { values: ['--role', '--file'] });
    checkRole(required(map, '--role'), tablePath(map));
  }
  if (sub === 'roles') {
    const map = parse(rest, { values: ['--file'] });
    const table = tableAssignments(tablePath(map)).map((a) => `${a.role} ${a.text} ${a.runtime}`);
    process.stdout.write(table.length === 0 ? '' : `${table.join('\n')}\n`);
    process.exit(0);
  }
  throw new UsageError(`dispatch: unknown table command: ${sub ?? '(none)'}`);
}

/**
 * A selection that is not a run is the seam's answer, not a malformed
 * invocation: exit 3 for a wait and 4 for a role with nothing left. The text
 * names the answer, and the error carries the code that says which it is.
 */
function refuseSelection(decided: Refusal): never {
  if (decided.kind === 'blocked') {
    throw new DispatchError(
      `dispatch: blocked until ${iso(decided.earliest)} (${decided.reason}): ${decided.routes.join(',')}`,
      3,
    );
  }
  throw new DispatchError(`dispatch: unroutable: ${decided.routes.join(',')}`, 4);
}

/**
 * Plan ROLE BRIEF DIR: resolve one attempt and print the argv that runs it.
 * The record is `key|level|runtime`, an empty level an empty field, then the
 * command on its own line; metered is the shell's reading of the runtime.
 */
function cmdPlan(argv: string[]): never {
  const map = parse(argv, {
    values: ['--role', '--brief', '--dir', '--file', '--model', '--thinking', '--session'],
  });
  const role = one(map, '--role') ?? '';
  const brief = one(map, '--brief') ?? '';
  const dir = one(map, '--dir') ?? '';
  if (!role || !brief || !dir) throw new UsageError('dispatch: ROLE, BRIEF and DIR are required');
  // Every outcome that lets a walk advance leaves its route unselectable
  // (cooled, dead, or a stop), so selecting over the whole role list visits
  // each entry once and ends when nothing may be attempted.
  const at = now();
  const level = decodeLevel(one(map, '--thinking'));
  const decided = resolveAttempts(role, tablePath(map), load(defaultPath(), session()).routes, at, {
    pin: one(map, '--model'),
    level,
  });
  if (decided.kind !== 'run') refuseSelection(decided);
  const [assignment] = decided.candidates;
  const command = commandFor(assignment, { brief, dir, session: one(map, '--session') });
  // Pipe-separated with an empty level as an empty field: a tab is whitespace
  // to bash's IFS, so an empty tab field collapses and shifts the rest. The
  // command is the only field that can hold a space, and it is the rest of the
  // stream.
  process.stdout.write(`${assignment.key}|${assignment.level ?? ''}|${assignment.runtime}\n${command}\n`);
  process.exit(0);
}

// seats start|turn -- the seat run's two steps.
//
// start reads the role's candidates from the route memory, seats them by the
// rotation and writes the run to --state. turn takes one outcome per fired seat,
// records it into the memory, applies the seat rule and prints the next turn's
// orders or the run's verdict. The entrypoint fires the attempts; this decides
// them. The plan is NUL-delimited, so a field can carry any character and the
// reader never re-splits a line.
function printStep(state: SeatState, orders: SeatOrder[]): never {
  const fields = ['turn', String(state.turn)];
  orders.forEach((order) => {
    const { candidate } = order;
    fields.push('fire', String(order.seat), candidate.runtime, candidate.key, candidate.level ?? '', candidate.text);
  });
  process.stdout.write(`${fields.join('\0')}\0`);
  process.exit(0);
}

function cmdSeats(argv: string[]): never {
  const [step, ...rest] = argv;
  const path = defaultPath();
  if (step === 'start') {
    const map = parse(rest, { values: ['--state', '--role', '--seats', '--model', '--thinking', '--file'] });
    const statePath = required(map, '--state');
    const role = required(map, '--role');
    const count = decodeInt(one(map, '--seats') ?? '1', '--seats');
    const level = decodeLevel(one(map, '--thinking'));
    const pin = one(map, '--model');
    const at = now();
    const memory = load(path, session());
    // A cooldown and a dead route are different answers, so the refusal is the
    // selection's, not a length test over the candidate list. A caller who
    // names the assignment instead takes it as given, so every seat runs that
    // one assignment: a repeat is the caller's choice, not a routing decision.
    const decided = resolveAttempts(role, tablePath(map), memory.routes, at, { pin, level });
    if (decided.kind !== 'run') refuseSelection(decided);
    const state = startSeats(count, decided.candidates, pin !== undefined);
    state.turn = 1;
    writeJson(statePath, state);
    printStep(state, seatOrders(state, memory.routes, at));
  }

  if (step === 'turn') {
    const map = parse(rest, {
      values: ['--state', '--at'],
      lists: ['--seat', '--rc', '--log'],
    });
    const statePath = required(map, '--state');
    const state = decodeSeatState(readJson(statePath));
    if (state === undefined) throw new DispatchError(`dispatch: seats turn: the run state is unreadable: ${statePath}`);
    const seats = (map.get('--seat') ?? []).map((value) => decodeInt(value, '--seat'));
    const rcs = (map.get('--rc') ?? []).map((value) => decodeInt(value, '--rc'));
    const logs = map.get('--log') ?? [];
    if (seats.length === 0) throw new UsageError('dispatch: seats turn needs at least one --seat/--rc/--log triple');
    if (seats.length !== rcs.length || seats.length !== logs.length) {
      throw new UsageError('dispatch: seats turn needs one --seat, one --rc and one --log per seat');
    }
    const at = decodeNumber(one(map, '--at'), '--at') ?? now();
    const attempts = seats.map((seat, index) => ({
      seat,
      rc: rcs[index],
      logText: tail(logs[index], 4000),
    }));
    const turn = seatTurn(state, attempts, load(path, session()).routes, at);
    recordOutcomes(path, session(), turn.writes);
    writeJson(statePath, state);
    for (const note of turn.notes) {
      process.stderr.write(`dispatch: seat ${note.seat} ended ${note.class} (${note.scope})\n`);
    }
    if (turn.kind === 'stopped') {
      process.stderr.write(`dispatch: seat ${turn.seat} ${turn.why}, so the run stops\n`);
      process.exit(turn.exit);
    }
    if (turn.kind === 'refusal') refuseSelection(turn.refusal);
    if (turn.kind === 'finished') {
      process.stdout.write('finished\0');
      process.exit(0);
    }
    printStep(state, turn.orders);
  }

  throw new UsageError(`dispatch: unknown seats step: ${step ?? '(none)'}`);
}

// walk -- whether a failed attempt may be followed by another. The policy lives
// in the library so the entrypoint only fires and reports.
function cmdWalk(argv: string[]): never {
  const map = parse(argv, { values: ['--class', '--scope'], switches: ['--worker', '--tree-changed', '--empty-log'] });
  const emptyLog = map.has('--empty-log');
  const facts = {
    class: decodeEnum(one(map, '--class') ?? '', CLASSES, '--class'),
    scope: decodeEnum(one(map, '--scope') ?? 'none', SCOPES, '--scope'),
    emptyLog,
  };
  const decision = map.has('--worker')
    ? decideWalk({ mode: 'worker', ...facts, treeChanged: map.has('--tree-changed') })
    : decideWalk({ mode: 'general', ...facts });
  if (decision.advance) {
    process.stdout.write('advance\n');
    process.exit(0);
  }
  throw new DispatchError(`dispatch: not retried: ${decision.reason}`);
}

function tail(file: string, limit: number): string {
  try {
    return readFileSync(file, 'utf8').slice(-limit);
  } catch {
    return '';
  }
}

const [command, ...rest] = process.argv.slice(2);
refusing(() => {
  switch (command) {

  case 'record':
    cmdRecord(rest);
    break;
  case 'refusal':
    cmdRefusal(rest);
    break;
  case 'classify':
    cmdClassify(rest);
    break;
  case 'status':
    cmdStatus(rest);
    break;
  case 'table':
    cmdTable(rest);
    break;
  case 'plan':
    cmdPlan(rest);
    break;
  case 'seats':
    cmdSeats(rest);
    break;
  case 'walk':
    cmdWalk(rest);
    break;
  default:
    throw new UsageError(`dispatch: unknown command: ${command ?? '(none)'}`);
  }
});
