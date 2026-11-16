# The change lifecycle's source

`chart.mmd` is the one Mermaid chart that [`change_pipeline.md`](../../../docs/reference/change_pipeline.md) renders; `transitions.md` is the transition table it renders. `ChangeModel.tla` and `ChangeModel.cfg` are the TLC module and its config. The chart covers the branch's life from its fork to its deletion; the mergeability relation is its axis. `scripts/check_change_pipeline.sh` reads this directory, holds the rendered copy to it, and `--write` regenerates the copy.
