# Assertion patterns

Open this when you choose what a unit asserts.

## Assert the positive

When a test is tempted to assert the absence of a wrong variant, assert the required behaviour instead. There are infinite wrong variants; the required one is the invariant. If the documentation says "required", it cannot also claim a default, so testing "required" is sufficient.

```bash
# Wrong: fragile, infinite wrong variants
if grep -q 'default: opencode' "$SCRIPT"; then
  fail "should not claim a default"
elif grep -q 'required' "$SCRIPT"; then
  pass "documents as required"
fi

# Right: positive assertion only
if grep -q 'required' "$SCRIPT"; then
  pass "documents as required (no default)"
else
  fail "does not document as required"
fi
```

## Assert the meaning, not the string

When a unit asserts an output, assert the behaviour a reader cares about, not the exact string the change happened to produce. Prefer "the provider cell shows the provider" over "the cell does not contain the old suffix". Freeze a user-visible format only after the operator accepts it, and record why the format is a contract. A test that pins an exact string or byte class cites the record that decides the pin (a roadmap item, an ADR, or a design record) in the test or its header comment; an uncited pin is change-mirror risk.

**The change-mirror form.** A unit added in the same change that asserts the absence of the string the change removed, or states the exact output of the formatter the change introduced, fails only if the change is reverted. It mirrors the edit and does not check the product.

**The removed-design form.** A unit that pins the removal of a design asserts a fact true of every implementation: a name no code creates stays absent, or a stale value stays untouched. Both hold however the code is written, so the unit cannot fail for a reason that matters. Rewrite it against the guard the code provides today, and rename it to say what it now guards.

## Pin the contract, not the accident

A behaviour no one decided is an accident of the current code, and a unit that pins it turns the next correct change red: the fix has to break the test first. Ask what decided the behaviour - an ADR, a design record, a usage the operator confirmed - and pin that. Where the record is silent and the behaviour matters, the unit waits, because writing it now pins a candidate and makes the decision harder.

## A rename is not a rewrite

A weak unit stays weak when only its name changes. When a unit is being fixed, the change is to the assertion: state what the unit is supposed to test, assert that, and let the name follow. A commit that renames a unit and leaves its body alone keeps the same blind evidence behind a better label.

## Never test a copy

When a test needs a production function, never inline a copy of it: the copy diverges while the tests stay green. Extract the function from the live source at run time, or drive the real entry point end to end. When you extract with a pattern, the test states the pattern in a prerequisite gate that fails with one named error when the function is renamed, moved or restructured.

```bash
source_function_from() {
  local FILE="$1" NAME="$2" SRC
  SRC="$(sed -n "/^${NAME}()/,/^}/p" "$FILE")"
  ...
}
```

A source-grep test that never executes the target is the same pattern in weaker form; the meaningful guard is behavioural coverage of the injection point, not text matching.

## Use a fixture, not a whole-tree scan

When the rule is about what a document or test must look like, assert it with fixtures that carry the positive and negative cases. A unit that lints or scans the whole project as its assertion checks project identity, not rule behaviour: the tree is not guaranteed to contain the negative cases, and the scan re-does the lint gate's work. A whole-tree conformance smoke is acceptable only when it is cheap and the scanned corpus is exactly the object the rule governs.

## Name the behaviour in the label

When you call an assertion, give it a label that names the behaviour under test, never a restatement of the values. A failure then names the behaviour, not just the mismatch.

## Capture and assert a command's rc and output

When a command's exit status or output is the subject, use `assert_run EXPECTED_RC CMD [LABEL]`: it runs the command in a subshell, asserts the status, and keeps the combined output in `RUN_OUT` for a following `assert_contains`. A mismatch names the captured output.

Some commands return non-zero as a signal, not an error, and `|| true` after them is load-bearing: `git diff` returns 1 when it finds differences, `grep -c` returns 1 when it finds no match, and a sourced preflight may legitimately exit. Do not strip a mask that tolerates this. Do not add one to a plain command whose rc 0 means success; prefer `assert_run` and an assertion.
