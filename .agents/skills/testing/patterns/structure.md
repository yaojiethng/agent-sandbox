# Structure patterns

Open this when you shape a test file or decide how many units it holds.

## One file, one registration block, one test_done

The shape is mandatory, not advisory. A test file opens with `test_setup` at file scope, defines one `test_*()` function per unit, registers each with `run_test`, and ends with one `test_done`. Nothing follows `test_done`: a registration after it is dead, and a second `test_done` splits the report. Every test body calls `pass` or `fail` at least once, because `run_test` fails a unit that completes without an assertion.

Copy [`../assets/test-file-template.md`](../assets/test-file-template.md) to start a file.

## The file is named for its subject

A test file is named for its subject and holds that subject's units: `tests/test_A.sh` tests `A.sh`, and the file name is the lookup for where that subject is covered. Keep no roster of which file covers what - it goes stale as soon as a subject moves, and it is one more thing to keep true.

## Document an untested branch at the code

When a function has a documented branch with no test, state why in the function's header comment at the point of the code. There is no central known-gaps file; the comment travels with the code.

## One unit per behaviour

When two units assert the same property, keep one and fold any extra clause into the survivor. A pair that genuinely differs differs in a named behaviour, and each name states its own. A unit that re-covers a rule the repository gate already owns is deleted rather than kept as a second opinion, because the gate is that rule's authority.
