# Writing a code-review runbook

A runbook is one file a fresh context reads with one scope, and it is what this shell dispatches to. The shell supplies the environment and the run's machinery; the runbook supplies the standard the reviewer judges against.

Write the centre first: the standard this review applies, or the residue it hunts.

State what the runbook accepts and what it returns. The shell dispatches on the first and reads the second back, so a runbook that omits either is not yet accepted whatever its headings. Everything else -- the questions it asks, its verdict, the cases it leaves alone -- is the review's own.

A runbook that returns a verdict uses the family's words: `HOLD` when its holding condition is met, naming the finding that fails, and `APPROVE` otherwise, its findings still carried. The runbook states the condition, never the vocabulary.

A runbook names no model, role, provider, seat count, project path or tool: it is read outside this repository as easily as inside it, so the environment is the shell's to state. A directory beside the runbook is not a project path: an entry cited as `p-31` is found in `patterns/` beside the file that names it.
