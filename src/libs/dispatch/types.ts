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

export type Verdict = {
  class: OutcomeClass;
  scope: Scope;
  reason?: Reason;
  refreshAt?: number;
};

export type RouteRecord =
  | { state: 'untried' }
  | { state: 'ready' }
  | { state: 'cooling'; until: number; reason: Reason; strikes: number; text?: string }
  | { state: 'dead'; text?: string };

export type RouteTable = Record<string, RouteRecord>;

export type Outcome = {
  at: number;
  class: OutcomeClass;
  scope: Scope;
  reason?: Reason;
  refreshAt?: number;
  text?: string;
  metered?: boolean;
};

export type State = {
  version: 1;
  session: string;
  routes: RouteTable;
  usage: Record<string, number>;
};

export type Selection =
  | { kind: 'run'; entry: string }
  | { kind: 'blocked'; earliest: number; reason: Reason; routes: string[] }
  | { kind: 'unroutable'; reasons: { route: string; text?: string }[] };
