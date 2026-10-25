// The walk's advance rule: whether a failed attempt may be followed by another
// entry's attempt.
//
// This is the one home of the rule. The shell entrypoint fires processes and
// reads their logs; it asks here whether the outcome allows another attempt,
// rather than restating the route policy beside it.

import type { OutcomeClass, Scope } from './types.ts';


export type WalkInput =
  | {
      mode: 'general';
      class: OutcomeClass;
      scope: Scope;
      /** Whether an attempt exited zero having written nothing to its log. */
      emptyLog: boolean;
    }
  | {
      mode: 'worker';
      class: OutcomeClass;
      scope: Scope;
      /** Whether the attempt changed the tree: a changed tree stops the walk. */
      treeChanged: boolean;
      emptyLog: boolean;
    };

export type WalkDecision = { advance: true } | { advance: false; reason: string };

export function decideWalk(input: WalkInput): WalkDecision {
  // An exit zero with an empty log is evidence of nothing, so it is a failure
  // rather than a success, whichever mode asked.
  if (input.emptyLog) {
    return { advance: false, reason: 'the attempt exited 0 with an empty log, so no work is evidenced' };
  }
  // A timeout would cost the next entry the same budget with no evidence it
  // fares better.
  if (input.class === 'timeout') {
    return { advance: false, reason: 'a timeout is the same budget again' };
  }
  // No model repairs a request or an unfunded account, so this stop is the
  // same whichever mode asked.
  if (input.class === 'capability' && (input.scope === 'request' || input.scope === 'account')) {
    return { advance: false, reason: 'the repair is not another model' };
  }
  // A worker's extra stop is the tree: a second model over a first model's
  // edits mixes two workers' work.
  if (input.mode === 'worker') {
    if (input.treeChanged) return { advance: false, reason: 'the attempt left a change set, so a second model would mix two workers\' work' };
    return { advance: true };
  }
  // An unclassified failure is not guessed at.
  if (input.class === 'unknown') {
    return { advance: false, reason: 'the failure is not classified' };
  }
  return { advance: true };
}
