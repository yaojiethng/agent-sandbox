#!/usr/bin/env bash
# libs/time_format.sh
#
# The one harness timestamp format. Every stamp the harness chooses is
# `YYYYMMDD-HHMMSS` in UTC: eight date digits, a hyphen, six time digits.
# An eval snapshot's `SNAPSHOT_TIME` is a harness stamp, not an external
# artifact exception: the snapshot directory and its status file carry the same
# shape. An observed file mtime or other metadata is not a harness stamp and is
# outside this rule.
#
#   ts_now_utc       --  the current stamp
#   ts_date_days_ago --  a UTC date stamp DAYS ago, for a date window
#   ts_epoch TS      --  a stamp as epoch seconds; empty when unparseable
#   ts_from_epoch E  --  epoch seconds as a stamp; empty when absent
#
# UTC, never the host's local clock: two hosts in two time zones must order the
# same session identically, and a stamp that moves with the host cannot be
# compared with one that did not. `ts_now_utc` names the one function that
# chooses a clock; `ts_epoch` and `ts_from_epoch` are its deterministic
# conversions. This file is the only one that calls `date` with a display
# format; every other producer calls these helpers or `date +%s` for epoch
# arithmetic. A producer outside this file that spells the format is a second
# definition; `tests/test_time_format.sh` fails on one.
#
# The epoch helpers require GNU date (`-d`), which the harness already relies on
# for every relative-time read.

TS_FORMAT='%Y%m%d-%H%M%S'
TS_PATTERN='^[0-9]{8}-[0-9]{6}$'
TS_DATE_FORMAT='%Y%m%d'

# ts_now_utc  --  the current UTC stamp.
ts_now_utc() {
  date -u +"$TS_FORMAT"
}

# ts_date_days_ago DAYS  --  the UTC date stamp DAYS ago, used for date windows.
ts_date_days_ago() {
  local days="${1:?ts_date_days_ago requires a day count}"
  date -u -d "$days days ago" +"$TS_DATE_FORMAT" 2>/dev/null
}

# ts_from_epoch EPOCH  --  EPOCH seconds rendered as a stamp; empty when absent.
ts_from_epoch() {
  local epoch="${1:-}"
  [[ -n "$epoch" ]] || return 0
  date -u -d "@$epoch" +"$TS_FORMAT" 2>/dev/null
}

# ts_epoch TS  --  TS parsed to epoch seconds; empty when it is not a stamp.
ts_epoch() {
  local ts="$1" d
  [[ "$ts" =~ $TS_PATTERN ]] || { echo ""; return 0; }
  d="${ts:0:4}-${ts:4:2}-${ts:6:2} ${ts:9:2}:${ts:11:2}:${ts:13:2}"
  date -u -d "$d" +%s 2>/dev/null
}
