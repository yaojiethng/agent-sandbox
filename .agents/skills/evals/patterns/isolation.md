# Give every cell its own isolation root

A run is evidence only if nothing outside it reached in. The clone isolates the repository and nothing else, so the rest of the environment has to be cut on purpose.

**The root.** One cell, one root, and every path in it is descended from that root: the clone, the temporary directory, and the logs. `TMPDIR` is the part that gets forgotten, and it is the part that carries the damage, because every tool a run spawns defaults to one shared `/tmp`.

**The name.** The root's path is read by the model before it reads anything else, so the path must say nothing about the experiment. A path that names a run, a cell or a case tells the model it is inside an experiment, and it will reason from that.

**The reach.** A root is useless if its ancestors hold the experiment. The run's brief, the other cells and the case files must not be reachable from the cell's root by walking up the tree.

| Instead of | Give |
|---|---|
| `/tmp/<whatever>` for every cell | `TMPDIR=$ROOT/tmp`, one per cell |
| `<experiment>/work/cell-3` | `~/runs/<uuid>/repo`, naming nothing |
| the brief and the other cells one `..` away | the archive written after the run, outside every ancestor |
| trusting that a cell stayed put | a measure that counts every path outside the root as an escape |

**The test.** Take any path a cell wrote, resolve the deepest directory that holds experiment material, and check it is not an ancestor of the cell's root. If it is, the cell is not evidence, whatever it reported. The harness counts a path outside the root as an escape, and an escaped run is invalid.
