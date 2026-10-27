---
reader: [agent, operator]
---

# Review runbook template

A runbook is one file a fresh context reads with one scope, and it is what a review shell dispatches to. The shell supplies the environment and the run's machinery; the runbook supplies the standard the reviewer judges against.

Copy these slots into a runbook and fill each one. A slot the review does not need is deleted rather than left blank: a blank scope is the fault that makes "a runbook that accepts no scope is a fault" unobservable.

| Slot | What the runbook states |
|---|---|
| Scope accepted | the kinds it takes -- a delta reads a diff, a set reads what is there -- and what each kind resolves to |
| Focus | what may narrow a run, and that anything outside the scope is a refused dispatch |
| Returns | the shape of a finding, and of the report |
| Verdict | whether one is given, and its words; a narrowed run gives none |
| Does not judge | the neighbouring cases this review leaves alone |

The template is open to extension by one move: add a row here, and fill it in the runbooks that need it. A rule every future runbook must carry belongs in a row; a rule one review contributes belongs in that review.

A runbook names no model, role, provider, seat count, project path or tool: it is read outside this repository as easily as inside it, so the environment is the shell's to state. A directory beside the runbook is not a project path: an entry cited as `p-31` is found in `patterns/` beside the file that names it.
