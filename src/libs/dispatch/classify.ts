// Turn a provider's own sentence into a verdict. The list is declared data: the
// order is the precedence, the first match wins, and a text outside the list is
// `unknown` rather than a guess.
//
// Every pattern carries an id so a test can assert the mapping by name, and so
// the unknown share can be counted per pattern rather than per class.

import type { OutcomeClass, Reason, Scope } from './types.ts';

type Pattern = {
  id: string;
  re: RegExp;
  class: OutcomeClass;
  scope: Scope;
  reason?: Reason;
  refresh?: 'utc-midnight';
};

export const PATTERNS: Pattern[] = [
  {
    id: 'rate-limit',
    re: /Rate limit exceeded|rate_limit_exceeded|\b429\b/i,
    class: 'quota',
    scope: 'none',
    reason: 'rate',
  },
  {
    id: 'plan-limit',
    re: /FreeUsageLimitError|GoUsageLimitError|usage limit/i,
    class: 'quota',
    scope: 'account',
    reason: 'quota',
    refresh: 'utc-midnight',
  },
  {
    id: 'funds',
    re: /Insufficient account funds|Insufficient funds/i,
    class: 'capability',
    scope: 'account',
  },
  {
    id: 'client-refused',
    re: /FreeTierError|can only be used from within|Provider is not configured/i,
    class: 'capability',
    scope: 'provider',
  },
  {
    id: 'model-unavailable',
    re: /Model access is disabled|Model is unavailable/i,
    class: 'capability',
    scope: 'model',
  },
  {
    id: 'auth',
    re: /AuthError|authentication_error|api_key_expired|Invalid API key|API key expired|User not found/i,
    class: 'capability',
    scope: 'account',
  },
  {
    id: 'bad-request',
    re: /invalid_request_error|Failed to deserialize/i,
    class: 'capability',
    scope: 'request',
  },
  {
    id: 'transport',
    re: /ECONNRESET|ECONNREFUSED|EPIPE|socket hang up|ETIMEDOUT|\b50[234]\b|overloaded/i,
    class: 'transient',
    scope: 'none',
    reason: 'flaky',
  },
  // The next two lines are the supervisor's own, written into a log when it ends
  // an attempt. They sit after the provider's patterns on purpose: a provider
  // that named its own failure is classified by that name, and these answer
  // only for a log the provider left silent.
  {
    id: 'silent-attempt',
    re: /no output for \d+s/i,
    class: 'transient',
    scope: 'none',
    reason: 'flaky',
  },
  {
    id: 'attempt-timeout',
    re: /the time limit of \d+s expired/i,
    class: 'timeout',
    scope: 'none',
    reason: 'timeout',
  },
];

export type Classification = {
  id: string;
  class: OutcomeClass;
  scope: Scope;
  reason?: Reason;
  refreshAt?: number;
};

// The next UTC midnight at or after `at`. The free tier replenishes on that
// clock, so the declared reset is computed rather than guessed.
export function nextUtcMidnight(at: number): number {
  const day = 24 * 60 * 60 * 1000;
  return Math.floor(at / day) * day + day;
}

export function classify(text: string, at: number): Classification {
  for (const p of PATTERNS) {
    if (!p.re.test(text)) continue;
    return {
      id: p.id,
      class: p.class,
      scope: p.scope,
      reason: p.reason,
      refreshAt: p.refresh === 'utc-midnight' ? nextUtcMidnight(at) : undefined,
    };
  }
  return { id: 'unclassified', class: 'unknown', scope: 'none' };
}
