---
date: 2026-10-16
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - The dispatch-CLI pin and gate

## Objective

Give `opencode-ai` one pinned version and one check, and fix the header that named the wrong file. Nothing checked the dispatch CLI's install, and the pi image installed it in a way that never produced a working binary.

## Scope

The two provider bases' install lines, their comments, and one check in the shared-base contract suite. The install's **home** is out of scope: it is the layer install design row's decision, and the roadmap already files it there.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One pinned version across every install | `bash tests/test_shared_base_contract.sh`, `test_opencode_ai_installs_are_pinned` and `test_opencode_ai_pins_agree` | Agent [x] |
| The header names the right file | `src/reasoning/providers/opencode/base.dockerfile` line 1 now reads the path it is | Agent [x] |
| A check fails on an unpinned install | mutation in a throwaway copy: the pin case failed; a multi-line unpinned install failed it too | Agent [x] |
| A check fails on disagreeing pins | mutation: `@1.20.0` against `@1.19.1`, `test_opencode_ai_pins_agree` failed | Agent [x] |
| A check fails on an install that cannot run | mutation: `--ignore-scripts` on an `opencode-ai` install, `test_opencode_ai_installs_produce_a_working_binary` failed | Agent [x] |
| The gate is not fooled | a chained `RUN` whose flag belongs to another command is not flagged; a multi-line instruction is read; `npm i`, `pnpm add`, `yarn add` and `bun add` are read | Agent [x] |
| Gates clean | shellcheck clean across 176 files; `bash scripts/lint.sh` clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The install stays in two homes for now | a shared tier would also ship the CLI into the hermes image, while provider bases install it twice; the trade-off is the layer install design row's named options, and the roadmap files that clause there | [`devlog/roadmap.md`](../../roadmap.md) |
| The check reads the install flags as well as the pin | the pin alone left an inert install unnoticed | the suite |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The pi image's dispatch install was inert. `pi/base.dockerfile` installed `opencode-ai@1.19.1` with `--ignore-scripts`, which skips the package's `postinstall`; that script writes the platform binary at `bin/opencode.exe`, the path the package's `bin` entry names, so the installed `opencode` was a stub that errors. The provider-decision unit introduced the install and no check read its flags. Fixed here, and the gate now fails on the flag. | defect, fixed | this record |
| A false negative the first check carried: a multi-line `RUN` instruction was invisible to it, so a copy whose only install was multi-line and unpinned passed. The second pass joins backslash continuations and splits commands before matching. | method | the suite |
| The package's `postinstall` is load-bearing, so any future security hardening that skips npm lifecycle scripts cannot apply to this install without another way to place the binary. | constraint | the layer install design row |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/providers/opencode/base.dockerfile`](../../../src/reasoning/providers/opencode/base.dockerfile) | the header, the pin, and the comment |
| [`src/reasoning/providers/pi/base.dockerfile`](../../../src/reasoning/providers/pi/base.dockerfile) | the `--ignore-scripts` flag dropped from the dispatch install, and the comment |
| [`tests/test_shared_base_contract.sh`](../../../tests/test_shared_base_contract.sh) | the install-scanning helpers and three cases |
| [`devlog/roadmap.md`](../../roadmap.md) | the row completed, with its home clause left to the layer install design row |
