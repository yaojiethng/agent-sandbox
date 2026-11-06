---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Implementation
status: Closed
---

# Handover - The reach table's setup route

## Objective

Make the reach gate fail when the `the project's own setup` row leaves `## Reach`, so every route the table states is checked rather than three of four.

## Scope

The roadmap row **The reach table's `the project's own setup` row is not verified**, under M3.3.2. The row offers two ends; this iteration takes the first, because the setup corpus is in the tree and can be derived.

The operator directed this iteration from the check-in inventory as **autopilot**; that direction is this iteration's release for both gates, so the scope proposal, acceptance criteria, pre-close summary and release gate are presented in the iteration report rather than awaited.

Out of scope: declaring the setup payload in `src/build/container-interface.json`. The manifest declares the image and the provision rows, and the setup route carries no image path; deriving the corpus from the `initialize` skill keeps the one declaration where the mechanism lives.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Removing any of the four `## Reach` rows fails the gate with a finding naming what moved | four probes over a taxonomy with one row removed each return rc=1 and name the missing side | Agent [x] |
| A project-setup corpus the table does not state is named | `bash tests/test_check_reach.sh` includes `test_setup_route_is_named` and passes | Agent [x] |
| A tree whose table states the setup route is clean | `bash tests/test_check_reach.sh` includes `test_stated_setup_route_is_clean` and passes | Agent [x] |
| The gate's `--root` seam reaches the scanner rather than being shadowed by the default | a fixture run scans the fixture root; `test_section_boundary` and the suite's fixture cases carry it | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Derive the setup roots from `workflow/*/skills/initialize/assets/conventions/` rather than add a manifest row | the setup corpus is the tree's project-setup payload, and the manifest declares image mounts, not the copy the `initialize` skill performs | this handover |
| Add the default `--root` only when the caller passes none | the scanner reads the first `--root` it finds, so the gate's own default shadowed every fixture seam | this handover; `scripts/check_reach.sh` |

## Decisions pending

None.

## Findings

| # | Finding | Type | Impact | Triaged to |
|---|---|---|---|---|
| 1 | `scripts/check_reach.sh` prepended `--root "$REPO_ROOT"` before the caller's arguments, so every `--root` fixture seam scanned the repository and the seam silently proved nothing | defect in the surface this iteration changed | the new check read the repository for its root | fixed in this iteration, `scripts/check_reach.sh` |

## Completed

| File | Change |
|---|---|
| [`scripts/lint/reach.mjs`](../../scripts/lint/reach.mjs) | a fifth check derives the project-setup corpus from the tree and names it when `## Reach` states no route |
| [`scripts/check_reach.sh`](../../scripts/check_reach.sh) | the default root is passed only when the caller names none, so the fixture seam reaches the scanner |
| [`tests/test_check_reach.sh`](../../tests/test_check_reach.sh) | the unstated setup route and its stated clean case, and the setup row added to the fixture writer |
