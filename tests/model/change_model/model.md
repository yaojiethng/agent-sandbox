# The change model's source

`chart.mmd` is the Mermaid chart that [`change_model.md`](../../../docs/reference/change_model.md) renders; `transitions.md` is the transition table it renders. `ChangeModel.tla` and `ChangeModel.cfg` are the TLC module and its config. `scripts/check_change_model.sh` reads this directory, holds the rendered copy to it, and `--write` regenerates the copy.
