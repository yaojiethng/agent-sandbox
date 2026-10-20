---
date: 2026-10-18
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - Dispatch improvements

## Objective

Replace the two error vocabularies with one verdict, so a dispatch failure states whether a retry can succeed, names what has to change first, and prints the provider's own sentence.

## Scope

Both classifiers were measured against the 88 distinct failure texts this deployment has recorded, not read and judged. The seam's `refusal_class` returned `unknown` on 80 of them, 90.9%, so its only output for nine failures in ten was a word and a log path. The extension's `classifyError` called 75 of 88 recoverable, 28 of which cannot self-heal: 12 account, 7 request, 6 model, 3 provider. Those retry for two minutes against a condition that does not change.

The corpus forced two definitions apart. Stopping an attempt is one question, because the OpenCode CLI retries a refusal silently so a refused attempt is spent either way. Whether the route can succeed later is another. A rate limit stops the attempt and is recoverable, so one flag cannot serve both, and the seam keeps two functions.

The scope vocabulary is five values plus a default, because the four responses to an unrecoverable failure differ: a model takes the next candidate, a provider is abandoned, a request is stopped rather than tried against every candidate, and an account needs the operator. Unrecognised text is unrecoverable, because a wrong stop costs a second and a wrong retry costs the candidate list.

Out of scope: routing `pi-reviewer-dispatch` through the seam, and a consolidated routing section in `AGENTS.md`. The measurement makes the second unnecessary, since the mechanism that needed documenting was a classifier nobody could read.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every measured failure text gets a verdict, and none is unclassified | `.scratchpad/dispatch/analyze.mjs`, unclassified 0 of 88 | Agent [x] |
| The implementation reproduces the measured verdict on the whole corpus | `/tmp/v2.mjs`, 79 of 79 non-aborted rows agree | Agent [x] |
| A cancelled turn recorded as an error is not the route's failure | `tests/extensions/pi/model-failover/classify.test.ts`, 9 of 9 aborted rows return ok | Agent [x] |
| The seam prints the provider's sentence on the failure line | `OPENCODE_DISPATCH_FALLBACK_CASES=1 bash tests/test_opencode_dispatch.sh`, 19 of 19 | Agent [x] |
| Removing the unrecoverable table fails the suite | `tests/extensions/pi/model-failover/mutation.test.ts`, `C1:limited-classification-dead` proven | Agent [x] |
| The invocation alone names the verdict and the message | operator reads one failed dispatch line and sees `verdict=` and `msg=` | Operator |

## Decisions

**A verdict replaces a class.** `classifyError` survives as a two-value shim over `classifyVerdict`, so the cooldown, the ledger and the report keep their shape. The alternative, carrying the scope through five consumers, buys only the request-scope case, which is filed as its own row.

**The seam keeps two questions, not one.** `refusal_in` ends a doomed attempt and includes a rate limit; `refusal_verdict` answers whether the route can succeed later and calls it recoverable. Collapsing them would either let a spent attempt run to its timeout or abandon a route on a rate limit.

**Unrecognised text is unrecoverable.** The measured default today is `transient` in the extension and `unknown` in the seam, and the two disagree on the same string. Both now stop.

**The message is printed, not summarised.** A class is a lossy summary of text nobody read, and it degraded to `unknown` for the string that explained the 403s.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Destination |
|---|---|---|---|
| The seam's classifier was `unknown` on 80 of 88 measured failures, 90.9%, so its output could not distinguish an expired key from a bad request | defect, measured | the operator read a log to learn what stopped a dispatch | resolved here |
| `classifyError` called 28 unrecoverable texts recoverable, including invalid API keys, malformed requests and disabled models | defect, measured | 13 retries over up to an hour against a condition that does not change | resolved here |
| A cancelled turn recorded with `stopReason: error` counted as a route failure | defect, measured | 9 of 88 corpus rows; a user abort cooled the route | resolved here |
| `tests/test_opencode_dispatch.sh` asserted `no output for 3s` while setting `OPENCODE_DISPATCH_STALL=2`, so `test_a_silent_attempt_is_stopped_and_falls_back` failed at `HEAD` | defect, pre-existing, one edit | the held-out fallback set could not pass | corrected in place, asserted against the variable |
| A request-scope failure still cools its route for the long window and counts toward demoting it | defect, filed | a caller-caused error demotes a healthy model | roadmap row `A request-scope failure still cools its route` |
| The text patterns are fitted to this corpus: 72 of 88 verdicts, 81.8%, rest on a text pattern and 16 on the HTTP status, which is protocol | limitation, measured | coverage on an unseen provider is an upper bound, not an estimate | stated in the scope |
| The seam's classifier reads a dispatch log and only one such log exists on disk, so its vocabulary can never be regression-tested against a live population; the session store is the only retained failure corpus | limitation, measured | the extension's corpus is measurable and the seam's is not | not filed |

## Completed

`classify.ts` gains `classifyVerdict`, `FailureScope`, `Verdict` and `isAborted`; `classifyError` becomes the two-value shim and `classifyOutcome` treats a cancelled turn as a success. `dispatch.sh` replaces `refusal_class` with `refusal_verdict`, adds `refusal_text`, and prints `verdict=` and `msg=` on the failure line; `refusal_in` widens to the unrecoverable families and keeps the rate-limit signature that ends a doomed attempt. Both installed copies are identical to the repository source. Four test files follow: `classify.test.ts` rebuilt over the measured families, a new `test_an_unrecoverable_refusal_names_its_scope` in the dispatch suite, the `C1` invariant statement, and the `C1` mutation row re-pointed at the new table so the gate still proves the break. The roadmap gains the resolving row and one filed follow-on.
