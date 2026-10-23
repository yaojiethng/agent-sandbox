#!/usr/bin/env node
// The command line of the dispatch library, called by scripts/dispatch.sh.
//
// It answers the role table's questions (a role's ordered entries, the
// assignment in force, the runtime that reaches an assignment, whether a role
// can run here) and it holds the route machine, the session memory and the argv
// shapes of each runtime.
//
// Exit codes: 0 run, 2 usage, 3 blocked, 4 unroutable.

import { readFileSync, writeFileSync } from 'node:fs';
import { classify } from './classify.ts';
import { binaryRuns, commandFor, opencodeBin } from './launch.ts';
import { applyClock, applyOutcome, select } from './machine.ts';
import { seatCandidates, seatOrders, seatResult, startSeats, seatVerdict } from './seats.ts';
import type { SeatState } from './seats.ts';
import { defaultPath, load, save } from './state.ts';
import { DispatchError, firstAssignment, parseAssignment, roleAssignments, tableAssignments } from './table.ts';
import type { OutcomeClass, Reason, Scope, State } from './types.ts';

function routeOf(entry: string): string {
  const at = entry.indexOf(' at ');
  return at === -1 ? entry : entry.slice(0, at);
}

function now(): number {
  return Number(process.env.DISPATCH_NOW ?? Date.now());
}

function fail(message: string, code = 2): never {
  process.stderr.write(`dispatch: ${message}\n`);
  process.exit(code);
}

function session(): string {
  return process.env.SESSION_ID || 'default';
}

function args(argv: string[]): Map<string, string[]> {
  const out = new Map<string, string[]>();
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith('--')) fail(`unexpected argument: ${key}`);
    const next = argv[i + 1];
    // A flag with no value is a switch; one followed by another flag is a
    // switch too, and its absence is caught where the value is required.
    const hasValue = next !== undefined && !next.startsWith('--');
    if (hasValue) i += 1;
    const list = out.get(key) ?? [];
    list.push(hasValue ? next : '');
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

// A refusal is the seam's own message on stderr and exit 1, so a caller reads
// the same text whether the shell or this CLI refused.
function refuse(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

function refusing<T>(run: () => T): T {
  try {
    return run();
  } catch (error) {
    if (error instanceof DispatchError) refuse(error.message);
    throw error;
  }
}

function cmdSelect(argv: string[]): never {
  // Entries are the only repeatable flag, so parse them directly.
  const list: string[] = [];
  let at = now();
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--entry') {
      const v = argv[i + 1];
      if (v === undefined) fail('missing value for --entry');
      list.push(v);
      i += 1;
      continue;
    }
    if (argv[i] === '--now') {
      const v = argv[i + 1];
      if (v === undefined) fail('missing value for --now');
      at = Number(v);
      i += 1;
      continue;
    }
    fail(`unexpected argument: ${argv[i]}`);
  }
  if (list.length === 0) fail('select needs at least one --entry');
  const path = defaultPath();
  const state = load(path, session());
  // The memory is keyed by route, and an entry carries a level beside it.
  const decided = select(list.map(routeOf), state.routes, at);
  if (decided.kind === 'run') {
    const entry = list.find((e) => routeOf(e) === decided.entry) ?? decided.entry;
    process.stdout.write(`run ${entry}\n`);
    process.exit(0);
  }
  if (decided.kind === 'blocked') {
    process.stdout.write(`blocked ${iso(decided.earliest)} ${decided.reason} ${decided.routes.join(',')}\n`);
    process.exit(3);
  }
  process.stdout.write(`unroutable ${decided.reasons.map((r) => r.route).join(',')}\n`);
  process.exit(4);
}

function cmdRecord(argv: string[]): never {
  const map = args(argv);
  const route = one(map, '--route') || fail('record needs --route');
  const klass = one(map, '--class') || fail('record needs --class');
  const scope = one(map, '--scope') || 'none';
  const reason = one(map, '--reason') || undefined;
  const refreshAt = one(map, '--refresh-at') || undefined;
  const text = one(map, '--text') ?? undefined;
  const at = Number(one(map, '--at') ?? now());
  const metered = map.has('--metered');

  const path = defaultPath();
  const state = load(path, session());
  const outcome = {
    at,
    class: klass as OutcomeClass,
    scope: scope as Scope,
    reason,
    refreshAt: refreshAt === undefined ? undefined : Number(refreshAt),
    text,
    metered,
  };
  state.routes[route] = applyOutcome(state.routes[route] ?? { state: 'untried' }, outcome);
  if (metered) state.usage[route] = (state.usage[route] ?? 0) + 1;
  save(path, state);
  process.stdout.write(`${JSON.stringify(state.routes[route])}\n`);
  process.exit(0);
}

function cmdClassify(argv: string[]): never {
  const map = args(argv);
  const text = one(map, '--text') ?? '';
  const at = Number(one(map, '--at') ?? now());
  const v = classify(text, at);
  process.stdout.write(`${v.id} ${v.class} ${v.scope} ${v.reason ?? '-'} ${v.refreshAt ?? '-'}\n`);
  process.exit(0);
}

function cmdStatus(argv: string[]): never {
  const map = args(argv);
  const path = defaultPath();
  const state: State = load(path, session());
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
function checkRole(role: string, file?: string): never {
  let last = '';
  for (const assignment of roleAssignments(role, file)) {
    if (assignment.runtime === 'pi') {
      if (binaryRuns('pi')) process.exit(0);
      last = `dispatch: role '${role}' needs the pi CLI, not on PATH`;
      continue;
    }
    const bin = opencodeBin();
    if (binaryRuns(bin)) process.exit(0);
    last = `dispatch: role '${role}' needs the opencode CLI, not runnable: ${bin}`;
  }
  if (last !== '') process.stderr.write(`${last}\n`);
  process.exit(1);
}

// resolveOne ROLE FILE ENTRY PIN  --  the assignment a caller will attempt.
//
// Nothing given resolves the role's head. An entry is a value from the role's
// own line, so its refusal is the table's. A pin is the caller's override, so a
// pin that is not `provider/model` says so about the pin.
function resolveOne(role: string, file: string | undefined, entry?: string, pin?: string): Assignment {
  if (pin !== undefined) {
    if (!pin.includes('/') || pin.endsWith('/')) {
      throw new DispatchError(`dispatch: the role's model '${pin}' is not provider/model`);
    }
    return parseAssignment(role, pin);
  }
  return entry === undefined ? firstAssignment(role, file) : parseAssignment(role, entry);
}

function cmdTable(argv: string[]): never {
  const [sub, ...rest] = argv;
  const map = args(rest);
  const file = one(map, '--file');
  const role = one(map, '--role') ?? '';
  refusing(() => {
    if (sub === 'list') {
      const list = roleAssignments(role, file).map((a) => a.text).join('\n');
      process.stdout.write(`${list}\n`);
      process.exit(0);
    }
    if (sub === 'resolve') {
      // An entry given outright is resolved as written, so a caller holding a
      // fallback or a pin asks about the assignment it will attempt rather than
      // about the role's head. A pin is the caller's own value, so a refusal
      // names that value instead of calling it a malformed table entry.
      const entry = one(map, '--entry');
      const pin = one(map, '--pin');
      const resolved = resolveOne(role, file, entry, pin);
      process.stdout.write(`${resolved.key} ${resolved.level ?? '-'} ${resolved.runtime}\n`);
      process.exit(0);
    }
    if (sub === 'check') {
      checkRole(role, file);
    }
    if (sub === 'roles') {
      const table = tableAssignments(file).map((a) => `${a.role} ${a.text} ${a.runtime}`);
      process.stdout.write(table.length === 0 ? '' : `${table.join('\n')}\n`);
      process.exit(0);
    }
    fail(`unknown table command: ${sub ?? '(none)'}`);
  });
}

// seats start|turn -- the seat run's two steps.
//
// start reads the role's candidates from the route memory, seats them by the
// rotation and writes the run to --state. turn takes one outcome per fired seat,
// records it into the memory, applies the seat rule and prints the next turn's
// orders or the run's verdict. The entrypoint fires the attempts; this decides
// them.
function printStep(state: SeatState, orders: { seat: number; entry: string; runtime: string }[]): never {
  process.stdout.write(`turn ${state.turn}\n`);
  orders.forEach((order) => {
    process.stdout.write(`fire ${order.seat} ${order.runtime} ${order.entry}\n`);
  });
  process.exit(0);
}

function cmdSeats(argv: string[]): never {
  const [step, ...rest] = argv;
  const map = args(rest);
  const statePath = one(map, '--state') || fail('seats needs --state');
  const at = Number(one(map, '--at') ?? now());
  const path = defaultPath();
  const memory = load(path, session());

  refusing(() => {
    if (step === 'start') {
      const role = one(map, '--role') || fail('seats start needs --role');
      const count = Number(one(map, '--seats') ?? '1');
      const candidates = seatCandidates(roleAssignments(role, one(map, '--file')), memory.routes, at);
      if (candidates.length === 0) {
        fail(`unroutable: ${role} names no candidate that may be attempted now`, 4);
      }
      const state = startSeats(role, count, candidates);
      writeFileSync(statePath, `${JSON.stringify(state)}\n`);
      const orders = seatOrders(state, memory.routes, at);
      state.turn = 1;
      writeFileSync(statePath, `${JSON.stringify(state)}\n`);
      printStep(state, orders.orders);
    }

    if (step === 'turn') {
      const state: SeatState = JSON.parse(readFileSync(statePath, 'utf8'));
      const results = map.get('--result') ?? [];
      for (const result of results) {
        const [seatText, rcText, logPath] = result.split(':');
        const seat = Number(seatText);
        const rc = Number(rcText);
        const text = tail(logPath, 4000);
        const applied = seatResult(state, seat, rc, text, at);
        const record = applied.record;
        if (record !== undefined) {
          memory.routes[record.route] = applyOutcome(memory.routes[record.route] ?? { state: 'untried' }, {
            at,
            class: record.class as OutcomeClass,
            scope: record.scope as Scope,
            reason: record.reason as Reason | undefined,
            refreshAt: record.refreshAt,
            text,
            metered: record.metered,
          });
          if (record.metered) memory.usage[record.route] = (memory.usage[record.route] ?? 0) + 1;
        }
        if (applied.outcome === 'stop') {
          save(path, memory);
          writeFileSync(statePath, `${JSON.stringify(state)}\n`);
          const why = record === undefined ? 'produced no output' : `ended ${record.class} (${record.scope})`;
          process.stderr.write(`dispatch: seat ${seat} ${why}, so the run stops\n`);
          process.exit(applied.exit);
        }
        if (applied.outcome !== 'done') {
          process.stderr.write(`dispatch: seat ${seat} ended ${record.class} (${record.scope})\n`);
        }
      }
      save(path, memory);

      if (state.stop !== 0) {
        writeFileSync(statePath, `${JSON.stringify(state)}\n`);
        process.exit(state.stop);
      }

      state.turn += 1;
      const next = seatOrders(state, memory.routes, at);
      writeFileSync(statePath, `${JSON.stringify(state)}\n`);
      if (next.orders.length === 0 && next.waiting > 0) {
        const held = state.slots.find((slot) => slot.state === 'active');
        const key = held === undefined ? '' : state.candidates[held.idx].key;
        const decided = select([key], memory.routes, at);
        const why = decided.kind === 'blocked' ? `${iso(decided.earliest)} ${decided.reason}` : 'no attempt left';
        process.stdout.write(`blocked ${why}\n`);
        process.exit(3);
      }
      const verdict = seatVerdict(state);
      if (verdict.done) {
        if (verdict.code === 0) process.stdout.write('finished\n');
        else process.stderr.write(`dispatch: unroutable: ${verdict.why}\n`);
        process.exit(verdict.code);
      }
      printStep(state, next.orders);
    }

    fail(`unknown seats step: ${step ?? '(none)'}`);
  });
}

function tail(file: string, limit: number): string {
  try {
    const text = readFileSync(file, 'utf8');
    return text.slice(-limit);
  } catch {
    return '';
  }
}

function cmdCommand(argv: string[]): never {
  const map = args(argv);
  const role = one(map, '--role') ?? '';
  const brief = one(map, '--brief') ?? '';
  const dir = one(map, '--dir') ?? '';
  const file = one(map, '--file');
  refusing(() => {
    if (!role || !brief || !dir) throw new DispatchError('dispatch: ROLE, BRIEF and DIR are required');
    const resolved = firstAssignment(role, file);
    const pinned = one(map, '--model') || resolved.key;
    const level = one(map, '--thinking') || resolved.level;
    // A pin arrives as provider/model, and the level is carried beside it.
    if (!pinned.includes('/') || pinned.endsWith('/')) {
      throw new DispatchError(`dispatch: the role's model '${pinned}' is not provider/model`);
    }
    const assignment = parseAssignment(role, level === undefined ? pinned : `${pinned} at ${level}`);
    const session = one(map, '--session');
    process.stdout.write(`${commandFor(assignment, { brief, dir, session })}\n`);
    process.exit(0);
  });
}

const [command, ...rest] = process.argv.slice(2);
switch (command) {
  case 'select':
    cmdSelect(rest);
    break;
  case 'record':
    cmdRecord(rest);
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
  case 'command':
    cmdCommand(rest);
    break;
  case 'seats':
    cmdSeats(rest);
    break;
  default:
    fail(`unknown command: ${command ?? '(none)'}`);
}
