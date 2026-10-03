# Agent Handover

**Date:** 2026-10-02
**Milestone:** M3 -- Autonomous Task Execution, Manual Review Workflow
**Type:** Documentation
**Status:** Closed

## Objective

Rewrite `docs/operations/provider_onboarding_guide.md` so it describes the system as built and stays short: point at the reference providers instead of restating their content, and correct the parts that name files and paths that do not exist.

## Scope

The onboarding guide, plus the one row in `tool_interface.md` that carries the same wrong file list. Documentation only. No script, Dockerfile, or test changes.

## Completed

| Work | Result |
|---|---|
| The guide went from 280 lines to 106 | every inlined sample replaced by a link to a shipped provider |
| Reference providers set to `pi` (fullest), `opencode` (minimal), `hermes` (multi-stage) | the three that exist, each named for the one shape it demonstrates |
| `claude-ai` and `claude-code` references removed | neither is a provider in this repository |
| `.env.example` step replaced by the `config/env.stub` mechanism, and the row dropped from the `tool_interface.md` interface table | no script reads `.env.example` and no provider ships one; `scripts/onboard.sh` renames `env.stub` to `.env` |
| Step 3's sample `provider.dockerfile` removed; the two things a provider must not write are named instead | the sample's COPY paths matched no shipped provider, and its fixed UID 1001 is the failure the `HOST_UID` threading prevents |
| Script and library paths corrected to `src/build/` and `src/libs/` | the guide pointed at a top-level `libs/` that does not exist |
| Step 11's provider-discovery claim replaced with how a provider is actually selected | no script scans `providers/*/base.dockerfile`; the agent names the provider at run time |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | The guide names no file or path that does not exist | every relative link in the guide resolves; the three named provider directories exist | Agent [x] |
| 2 | The guide is shorter than the file it replaces | `wc -l docs/operations/provider_onboarding_guide.md`, 106 against 280 | Agent [x] |
| 3 | The provider interface table in `tool_interface.md` matches the file list in the guide | read both; neither mentions `.env.example` | Agent [x] |
| 4 | The Markdown gate is clean | `bash scripts/check_markdown.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| `docs/operations/provider_onboarding_guide.md` | the rewrite |
| `docs/architecture/tool_interface.md` | the required-file table carries `.env.example`, which nothing reads |
| `devlog/roadmap.md` | the task row |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The guide links to the reference providers and drops the inlined sample Dockerfiles and compose | the samples had drifted from every shipped provider; a link to a file that is correct on every build cannot drift | the guide |
| The guide names `pi` as the full reference, `opencode` as the minimal one, `hermes` for multi-stage | each is the live example of one shape, and all three are the files an agent can read | the guide |
| `tool_interface.md`'s required-file table drops `.env.example` | no script reads it and no provider ships one; `config/env.stub` is the mechanism `scripts/onboard.sh` uses | `tool_interface.md` |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `claude-ai` and `claude-code`, named as the reference implementations throughout the guide, are not providers in this repository | documentation gap | Triaged to: Completed -- the guide now names the three shipped providers |
| `.env.example` is listed as a required provider file, but nothing reads it and no provider ships one | documentation gap | Triaged to: Completed -- dropped from the guide and from the `tool_interface.md` table |
| The guide's file tree is rooted at `providers/<n>/`; every provider lives at `src/reasoning/providers/<n>/` | documentation gap | Triaged to: Completed -- the tree is gone; each step names the repo-relative path |
| Step 3's sample `provider.dockerfile` copies to `/libs/`, `/usr/local/bin/provider-entrypoint.sh`, and `/opt/context/config/`, and creates the user at a fixed UID 1001; no shipped provider does any of these | documentation gap | Triaged to: Completed -- the sample is replaced by a link and a rule |
| The guide points at `libs/compose.sh` and `libs/snapshot.sh`; the real paths are `src/build/compose.sh` and `src/capability/snapshot.sh` | documentation gap | Triaged to: Completed |
| Step 11 claims the harness discovers providers by scanning `providers/*/base.dockerfile`; `scripts/onboard.sh` iterates the directory and seeds `config/`, with no such check | documentation gap | Triaged to: Completed -- rewritten as how a provider is selected |
| Nothing links to the removed steps by number, so no inbound link breaks | evidence | Triaged to: nothing -- verified, no action |

## Deferred items

| Item | Reason |
|---|---|

## What's Next

Nothing. The container images and the provider documentation both describe the system as built, and no deferred item from this iteration names a next piece of work.
