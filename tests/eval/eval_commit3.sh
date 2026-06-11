#!/usr/bin/env bash
# Commit 3 eval — gate adjacency fix, document disentanglement
set -euo pipefail

pass=0; fail=0; check() { local label="$1" pat="$2" file="$3" invert="${4:-}"; if [ -z "$invert" ]; then if grep -q "$pat" "$file" 2>/dev/null; then echo "  PASS: $label"; pass=$((pass+1)); else echo "  FAIL: $label"; fail=$((fail+1)); fi; else if grep -q "$pat" "$file" 2>/dev/null; then echo "  FAIL: $label"; fail=$((fail+1)); else echo "  PASS: $label"; pass=$((pass+1)); fi; fi; }

echo "=== iteration_policy.md ==="
check "C1: Gate 1 row requires session type presentation" "session type" docs/operations/iteration_policy.md
check "C2: Gate 1 exit includes 'Session type confirmed'" "Session type confirmed" docs/operations/iteration_policy.md
check "C3: Step 5 exit says 'Operator confirmed acceptance criteria'" "Operator confirmed acceptance criteria" docs/operations/iteration_policy.md
check "C4: Gate 2 exit says 'Operator confirmed criteria are satisfiable'" "Operator confirmed criteria are satisfiable" docs/operations/iteration_policy.md
check "C5: Gate 2 action requires AC table presentation" "present the acceptance criteria table" docs/operations/iteration_policy.md
check "C6: Step 5 uses four-column table format" "four-column table" docs/operations/iteration_policy.md
check "C7: Step 7 uses four-column AC status table" "four-column AC status table" docs/operations/iteration_policy.md
check "C8: Step 7 Details warns not to reuse Gate 2 format" "Do not reuse the Gate 2 format" docs/operations/iteration_policy.md
check "C9: Step Details section exists" "Minor Loop — Step Details" docs/operations/iteration_policy.md
check "C10: Step 1 Details includes recovery check rule" "Recovery check.*verify the roadmap" docs/operations/iteration_policy.md
check "C11: 'During the session' section exists in Step Details" "During the session" docs/operations/iteration_policy.md
check "C12: Step 7 Details includes propagation replay" "propagation replay" docs/operations/iteration_policy.md
check "C13: Steps 8-9 Detail includes scope reconciliation" "Scope reconciliation" docs/operations/iteration_policy.md
check "C14: Steps 8-9 Detail includes carry-forward resolution" "Carry-forward resolution gate" docs/operations/iteration_policy.md
check "C15: Steps 8-9 Detail includes mid-session triage" "Mid-session findings triage gate" docs/operations/iteration_policy.md
check "C16: Seed next session subsection exists" "Seed next session" docs/operations/iteration_policy.md

echo ""
echo "=== handover_policy.md ==="
check "D1: Role statement at top (first 5 lines)" "iteration_policy.md" docs/operations/handover_policy.md
check "D2: No Population Rules section" "## Population Rules" docs/operations/handover_policy.md "invert"
check "D3: No 'At Step' procedural headings" "### At Step 5" docs/operations/handover_policy.md "invert"
check "D4: Lifecycle references iteration_policy.md" "iteration_policy.md.*§Step 1" docs/operations/handover_policy.md
check "D5: Carried forward field uses 'per iteration_policy.md'" "Populated per .iteration_policy.md" docs/operations/handover_policy.md
check "D6: Hot files field uses 'per iteration_policy.md'" "Populated per .iteration_policy.md.*§Step 1" docs/operations/handover_policy.md
check "D7: References handover-audit.skill.md" "handover-audit.skill.md" docs/operations/handover_policy.md
check "D8: References new-session.md (not v2)" "new-session.md" docs/operations/handover_policy.md
check "D9: No reference to new-session-v2" "new-session-v2" docs/operations/handover_policy.md "invert"

echo ""
echo "=== new-session.md ==="
check "E1: Gate 2 section uses Verified by column" "Verified by" agent/prompts/new-session.md
check "E2: Gate 2 section includes pre-verification instruction" "Pre-verify every criterion" agent/prompts/new-session.md
check "E3: Create handover section references iteration_policy.md" "iteration_policy.md" agent/prompts/new-session.md
check "E4: Gate 2 uses four-column table format" "four-column" agent/prompts/new-session.md || true

echo ""
echo "=== handover-audit.skill.md ==="
check "F1: Audit skill file exists" "." agent/drafts/handover-audit.skill.md
check "F2: Contains spec-to-source integrity rule" "Spec-to-source integrity" agent/drafts/handover-audit.skill.md
check "F3: Contains structured output rule" "Structured output format" agent/drafts/handover-audit.skill.md
check "F4: Contains validation tool rule" "Validation tool coverage" agent/drafts/handover-audit.skill.md

echo ""
echo "=== Cross-document consistency ==="
check "G1: No stale handover_policy#at-session-open references" "handover_policy.md#at-session-open" docs/operations/iteration_policy.md "invert"
check "G2: No stale handover_policy#at-step-5 references in iteration_policy" "handover_policy.md#at-step-5" docs/operations/iteration_policy.md "invert"

echo ""
echo "=== RESULT: $pass PASS, $fail FAIL ==="
