# Eval failure modes

A behaviour eval fails in ways that look like results. This file names the modes that make a run unusable, what each one does to the run, and what the harness now does about it. It is prose, not a data file: add a mode when a run demonstrates it, and state the detector or the open gap beside it.

## Isolation

**A shared temporary directory.** Every tool a run spawns defaults to one `/tmp`, so one cell's report becomes another cell's input. A cell that reads a sibling's artefact is not measuring its own configuration. The harness counts every path outside the cell's root as an escape, and an escaped run is invalid. The prevention is [`patterns/isolation.md`](../patterns/isolation.md).

**A path that names the experiment.** The root's path is read before any file is opened, so a cell whose working directory names a run, a cell or a case reasons from the premise that it is inside an experiment rather than from the work. [`patterns/isolation.md`](../patterns/isolation.md) owns the naming rule.

**A clone under the experiment's own directory.** A brief, a case file or another cell one `..` away makes the experiment reachable, and the escape measure treats a reachable ancestor as a failed cell.

## Attribution and cost

**An auditor with no transcript.** A seat launched without a session file leaves no record of what it read or found, so its findings cannot be checked. The harness marks a run unattributed, and `--require-valid` refuses it.

**A clone with no git identity.** A clone inherits no identity, so a run that commits either stops on an unknown author or invents one. The harness sets the identity on every clone before the run starts.

**Cost read from the orchestrator alone.** A run's seats can out-write the orchestrator by an order of magnitude. Counting only the orchestrator's transcript understates the cost and hides the seats entirely. The session measure sums every session the run wrote.

## Measurement

**Validity tied to one provider's stop vocabulary.** A rule that treats anything but one provider's completion token as a failure will reject healthy turns from another provider. The harness treats only an abnormal terminator as invalid, and records the raw stop reasons for the benchmark.

**A cleanup scored with no denominator.** A report that finds defects without declaring the set it searched has no scale, so a count of findings cannot be compared across cells. Row A4 of [`references/specification.md`](../references/specification.md) carries the row and no field fills it yet.
