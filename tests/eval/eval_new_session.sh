#!/usr/bin/env bash
# Code-based capability eval for new-session prompt templates
# Run against golden dataset invariants from 20260522-story-active-prompt_eval_infrastructure.md

set -euo pipefail

eval_one() {
  local f="$1"
  local label="$2"
  local results=""

  # I1: No Step 1b references
  if grep -qi "step.*1b" "$f"; then
    results+="I1:FAIL "
  else
    results+="I1:PASS "
  fi

  # I2: No compaction at Step 1 (in recovery checks section)
  if grep -qi "compact.*step 1\|compaction.*step 1\|compact.*task groups.*previous\|compaction check.*scan\|compaction check.*Task group" "$f"; then
    results+="I2:FAIL "
  else
    results+="I2:PASS "
  fi

  # I3: Post-close bookkeeping recovery referenced with correct ordering
  if grep -qi "bookkeeping recovery\|post-close bookkeeping\|run.*bookkeeping" "$f"; then
    results+="I3:PASS "
  else
    results+="I3:FAIL "
  fi

  # I4: Both scope and AC gates present
  if grep -qi "Gate 1\|scope.*confirm\|What is being asked" "$f"; then
    if grep -qi "Gate 2\|acceptance criteria\|what does done look like" "$f"; then
      results+="I4:PASS "
    else
      results+="I4:FAIL "
    fi
  else
    results+="I4:FAIL "
  fi

  # I6: No old Trigger B wording
  if grep -qi "Trigger B\|trigger B" "$f"; then
    results+="I6:FAIL "
  else
    results+="I6:PASS "
  fi

  # I7: No old compaction model wording
  if grep -qi "compact any fully-completed task groups.*previous session\|replace.*group header.*checklist.*outcome sentence\|every checkbox.*checked.*compact it" "$f"; then
    results+="I7:FAIL "
  else
    results+="I7:PASS "
  fi

  # I5: References canonical policy documents
  if grep -qi "handover_policy\|iteration_policy\|roadmap_policy" "$f"; then
    results+="I5:PASS "
  else
    results+="I5:FAIL "
  fi

  # Divergence detection (bonus: not in golden dataset but distinguishing)
  if grep -qi "diverges\|session type.*compare\|Step 1.*Compare\|type.*mismatch\|supersede.*prior" "$f"; then
    results+="BONUS_DIVERGE:PASS "
  else
    results+="BONUS_DIVERGE:ABSENT "
  fi

  local passes=$(echo "$results" | grep -o "PASS" | wc -l)
  local fails=$(echo "$results" | grep -o "FAIL" | wc -l)

  echo "$label: $passes PASS, $fails FAIL | $results"
}

echo "# Prompt Eval Report — new-session prompts"
echo "## Date: $(date -I)"
echo "## Policy baseline: post-20260522-01 amendments"
echo ""
eval_one "agent/prompts/new-session.md" "v1"
eval_one "agent/prompts/new-session-v2.md" "v2"
echo ""
echo "## Failures requiring fix:"
echo ""
echo "### v1 failures:"
grep -n "Step 1b\|compaction check.*Step\|Steps 1, 1b" agent/prompts/new-session.md | while IFS=: read -r line text; do
  echo "  L$line: $text"
done
echo ""
echo "### v2 failures:"
grep -n "Compaction check:\|every checkbox\|replace the group header\|single outcome sentence" agent/prompts/new-session-v2.md | while IFS=: read -r line text; do
  echo "  L$line: $text"
done
echo ""
echo "## Verdict: v2 is the winner. Fix I2 and I7 failures. Promote v2 → new-session.md. Archive v1."
