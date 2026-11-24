# Timestamp Format

**Current:** 2026-11-24

## 2026-11-24 -- Every harness stamp is the harness format, and the eval snapshot is a harness stamp

**Decision:** Every timestamp the harness writes or reads is `YYYYMMDD-HHMMSS` in UTC, owned by `src/libs/time_format.sh`. `ts_now_utc` is the one wall-clock producer; `ts_epoch` and `ts_from_epoch` are the deterministic conversions. The eval snapshot's `SNAPSHOT_TIME` is a harness stamp: `package_eval_snapshot.sh` calls `ts_now_utc`, and `eval-point.json` and `.snapshot-status` carry the same shape. There is no external-artifact exception.

**Evidence:** Before this entry, `package_eval_snapshot.sh` computed `SNAPSHOT_TIME` with its own `date -u +%Y-%m-%dT%H:%M:%SZ`, while `export_path` named the snapshot directory with the harness clock helper. No file in the tree reads `SNAPSHOT_TIME` back, no reference document required ISO 8601, and the existing timestamp scan could not see the ISO spelling. `tests/test_package_eval_snapshot.sh` now asserts the facts and the status file carry the harness shape, and `tests/test_time_format.sh` rejects the compact, old-probe and ISO spellings at a producer.

**Rejected alternatives:**

- *Declare `SNAPSHOT_TIME` an external-artifact stamp with a named exception.* **Intent failure**: the harness writes it, nothing in the tree reads it, and the snapshot directory already carries harness time, so the exception would put two timestamp shapes inside one snapshot for a consumer requirement that does not exist.
- *Leave the claim and the producer unchanged.* **Execution failure**: the one-format claim is false, and the gate cannot see the format the snapshot uses.
- *Drop `SNAPSHOT_TIME`.* **Neither**: the snapshot facts need the time the snapshot was taken, and the directory prefix is not a substitute for the machine-readable field.
- *Give `ts_epoch` and `ts_from_epoch` the `_utc` suffix too.* **Neither**: they do not choose a clock; the suffix marks the producer, which is the one place a local-clock mistake can enter.

**Edge cases / drivers:** A reader outside the harness may consume the snapshot, but consumption does not make the stamp external: the harness wrote it and never reads it back. The snapshot directory prefix and the facts field are separate calls, so they carry the same shape and not necessarily the same second. An external producer's stamp is not a harness stamp; no such producer writes into this tree today.
