// The shared vocabulary of the dispatch machine. Types only, so the module
// erases to nothing under node's type stripping.

export type OutcomeClass =
  | 'success'
  | 'transient'
  | 'quota'
  | 'capability'
  | 'timeout'
  | 'unknown';

export type Scope = 'none' | 'model' | 'provider' | 'account' | 'request';

export type Reason = 'flaky' | 'rate' | 'quota' | 'timeout';

export type RouteRecord =
  | { state: 'untried' }
  | { state: 'ready' }
  | { state: 'cooling'; until: number; reason: Reason; strikes: number }
  | { state: 'dead' };

export type RouteTable = Record<string, RouteRecord>;

export type Outcome = {
  at: number;
  class: OutcomeClass;
  scope: Scope;
  reason?: Reason;
  refreshAt?: number;
};

/** One attempt's effect on the route memory, as the caller hands it back. */
export type OutcomeWrite = { route: string; outcome: Outcome; metered: boolean };

export type State = {
  version: 1;
  session: string;
  routes: RouteTable;
  usage: Record<string, number>;
};

/** Whether one route may be attempted at `now`, and why not when it may not. */
export type Availability =
  | { kind: 'run' }
  | { kind: 'blocked'; until: number; reason: Reason }
  | { kind: 'dead' };

/** A selection that did not find a route to attempt. */
export type Refusal =
  | { kind: 'blocked'; earliest: number; reason: Reason; routes: string[] }
  | { kind: 'unroutable'; routes: string[] };

/** The decision `select` takes over an ordered list of candidates. */
export type Selection<T extends { key: string }> = Refusal | { kind: 'run'; chosen: T };
