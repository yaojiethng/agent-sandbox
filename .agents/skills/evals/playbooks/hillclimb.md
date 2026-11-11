# Hillclimb evals

The procedure is stochastic hill climbing over a discrete neighbourhood: from a candidate, generate the neighbours one edit away, estimate each on the case's score tuple, and move only to a neighbour whose estimate exceeds the incumbent's by more than the band. It is derivative-free, so it needs a comparable score rather than a direction, and it is myopic, so the neighbourhood is fixed by the edit operator: the climb cannot leave the basin its incumbent sits in, and an axis the tuple does not read is invisible to it.

## Scope alignment for a climb

The phases, and the four parts of scope alignment, are [`../SKILL.md`](../SKILL.md) `## The workflow`'s. A climb's parts hold the following, and the mechanism is the agent's to choose while what the operator agrees is that the mechanism answers the invariant it is named for.

| Part | Holds | The agent supplies | Checked by |
|---|---|---|---|
| the intent | the claim; the target and its direction; that the tuple is the objective, the candidate is the batch's only variable, the gate is independent, and nothing outside the edit touches the tree | the tuple's axes and order, the case, and a check per assertion with its known-bad | the operator's reading of the tuple's order, and the batch, which shows whether the axes separate |
| the enforcement | that each invariant has a mechanism rather than a wish | the band a batch computes from its control, the batch construction, the regression gate, the blind grade, and the contrast that must lose | the proof on a contrast that must lose, then the gate that reads each mechanism |
| the deliverables | the verdict, the accepted edits as commits, one `decision.tsv` row per attempt, and the cost in runs and tokens | the artefacts, named and placed outside the tree | `## Close` of the skill, read against this table |
| the delivery | the shape of each artefact, and how the shape is validated | the verdict's fields, the log's columns, and the record's sections | `--check` for the declaration, the handover gate for the record, and the reader for the log |

At agree, a climb also fixes the target and the floor on attempts that make the stop predicate, the budget, and k for the plateau, because each is a number the run is judged against.

## Terms

| Term | Means |
|---|---|
| candidate | one instruction set, pinned as a commit |
| neighbour | the candidate plus or minus exactly one edit |
| measurement | the score tuple read from one batch's artefacts, at n runs per configuration |
| noise | the spread one configuration shows against itself inside one batch, at the same n |
| band | the noise, or the case's declared minimum detectable effect, whichever is larger |
| improvement | the first axis of the tuple that differs, in the target's direction, past the band, with every gate green |
| defect | a behaviour the operator names as wrong, reproduced by the case on the fixture |
| fix | an edit that removes the defect and puts no earlier behaviour below its gate, decided by one batch |
| plateau | k consecutive neighbours, none of them an improvement, with k agreed at scope |
| climb | the sequence of batches from the baseline candidate to the last accepted one |

## The procedure

`../SKILL.md` `## The protocol` holds for every batch and is not restated here; the climb adds the predicates below and finds its grader, band and decision rule there.

```text
PRECONDITIONS
  scope aligned, and every mechanism it names built and proven      [OP]
  the case reproduces the complaint: its control fails                  [PROG]
  the baseline recorded, and the regression gate green                  [PROG]
  the decision log opened outside the tree                              [PROG]

INVARIANTS
  the objective is a gradient: the target lies beyond the incumbent     [AGENT]
  the measurement is stationary: one edit moves the tuple further
    than identical text moves it between batches                        [PROG]
  the candidate is the batch's only variable                            [PROG]
  the gate is independent of the tuple                                  [DET]

PROCEDURE
  repeat
    ground one hypothesis in a mechanism the tuple can read             [AGENT]
    hand one edit to a subagent, and review the diff                    [AGENT]
      independent hypotheses run in separate worktrees                  [DET]
    measure one batch: incumbent as control, edit as treatment,
      both at n runs, in one pass                                       [PROG]
    accept if the batch shows an improvement, else revert in full       [DET]
    log the row, kept or reverted                                       [PROG]
    commit only an accepted edit, staging only its files                [PROG]
    refuse a commit that touches a forbidden path                       [DET]
    on a plateau, change the edit operator or the category              [AGENT]
  until the stop predicate is met                                       [DET]
     or the remaining neighbours are marginal for their cost            [AGENT]

POSTCONDITIONS
  every accepted edit is one commit, and every commit was measured      [PROG]
  the log holds one row per attempt and the band it was read against    [PROG]
  the verdict states the target, band, effect, accepted edits, cost
    in runs and tokens, and the threat the climb leaves open            [AGENT]
  the paired figures separated from the cross-batch ones                [AGENT]
```

Each tag names the source of the step. `[PROG]` is computed by the harness or a script, `[DET]` follows from a rule once the data is in, `[AGENT]` is a judgement the climbing agent makes from the evidence, and `[OP]` is the operator's agreement, which is a signature on a part of the contract rather than authorship of it. A step that carries two tags is two steps, and the split is where the rule ends and the judgement begins.
