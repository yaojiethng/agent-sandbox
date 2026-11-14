# The workflow statechart's source

`chart.mmd` is the main chart that [`workflow_statechart.md`](../../../docs/reference/workflow_statechart.md) renders; `discussion.mmd` is its discussion-record chart. `scripts/check_statechart.sh` reads both, holds the rendered blocks and the `## States` table to them, and `--write` regenerates the rendered copy.
