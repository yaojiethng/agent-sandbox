#!/usr/bin/env bash
# discovery_tar_filelist_parity.sh -- Discovery layer 1: file-list parity between the
# current snapshot pipeline (rsync working-tree copy + `git archive HEAD` baseline) and
# the proposed tar-only method (git-enumerated tar: `git ls-files` cached+untracked
# packed via `tar --null -T`).
#
# Builds a fixture tree covering the edge cases the snapshot pipeline must survive,
# runs both methods, and reports parity or divergence per case. This is a discovery
# probe, not a regression test: divergences are the finding, reported explicitly.
#
# Exit 0 = methods agree on the fixture matrix; exit 1 = divergences found (report
# printed); exit 2 = infrastructure failure (fixture build error, git/rsync error).
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$REPO_ROOT/src/capability/snapshot.sh"

WORK=$(mktemp -d /tmp/discovery-parity.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

PROJECT="$WORK/project"
mkdir -p "$PROJECT"
git -C "$PROJECT" init --quiet
git -C "$PROJECT" config user.email discovery@sandbox
git -C "$PROJECT" config user.name discovery

# ---------------------------------------------------------------
# Fixture tree
# ---------------------------------------------------------------
# Each case directory under fixture cases/ holds files relevant to one behavior.
mkdir -p "$PROJECT/src/deep" "$PROJECT/emptydir" "$PROJECT/ignored-dir" "$PROJECT/build"

# c1: committed + unmodified
echo one > "$PROJECT/src/committed.txt"
# c2: committed, then modified in the worktree
echo two > "$PROJECT/src/modified.txt"
# c3: committed, then deleted in the worktree (unstaged)
echo three > "$PROJECT/src/deleted.txt"
# c4: committed, then renamed in the worktree (unstaged: old missing, new untracked)
echo four > "$PROJECT/src/renamed.txt"
# c5: never-committed, not ignored
echo five > "$PROJECT/src/untracked.txt"
echo "deep content" > "$PROJECT/src/deep/nested.txt"
# c6: nested .gitignore ignoring one file in its own directory
printf 'secret.txt\n' > "$PROJECT/src/deep/.gitignore"
echo hidden > "$PROJECT/src/deep/secret.txt"
echo visible > "$PROJECT/src/deep/visible.txt"
# c7: root .gitignore rule
printf '*.log\nbuild/\n' > "$PROJECT/.gitignore"
echo logdata > "$PROJECT/app.log"
echo logdata > "$PROJECT/src/deep/app.log"
echo buildable > "$PROJECT/build/out.bin"
# c8+c9: global excludesFile and .git/info/exclude rules
echo global_excluded > "$PROJECT/globalonly.txt"
echo repo_excluded > "$PROJECT/repoonly.txt"
# c10: negation pattern in the global excludesFile (known rsync limitation)
echo negated > "$PROJECT/keep.debug"
echo negated > "$PROJECT/drop.debug"
# c11: symlink to a tracked file inside the tree
# c12: executable bit
# c13: empty directory (created above: emptydir/, ignored-dir/ is gitignored)
# c14: awkward names
echo spaces > "$PROJECT/has space.txt"
echo unicode > "$PROJECT/unicode-é中.txt"
# c15: binary-ish content
printf '\x00\x01\x02\xff' > "$PROJECT/binary.bin"

GLOBAL_EXCLUDES="$WORK/global-excludes"
printf 'globalonly.txt\n*.debug\n!keep.debug\n' > "$GLOBAL_EXCLUDES"
git -C "$PROJECT" config core.excludesFile "$GLOBAL_EXCLUDES"
printf 'repoonly.txt\n' > "$PROJECT/.git/info/exclude"

git -C "$PROJECT" add . 2>/dev/null || true
# c3/c4 need commit-then-worktree-change ordering
git -C "$PROJECT" commit --quiet --allow-empty -m baseline
git -C "$PROJECT" add .
git -C "$PROJECT" commit --quiet --allow-empty -m second
rm "$PROJECT/src/deleted.txt"
mv "$PROJECT/src/renamed.txt" "$PROJECT/src/renamed-moved.txt"
ln -sf committed.txt "$PROJECT/src/link-to-committed"
chmod +x "$PROJECT/src/untracked.txt"

failures=0
report() { # report CASE LABEL_A LABEL_B MATCH
  if [[ "$4" == "match" ]]; then
    printf '  %-46s %s\n' "$1" "PARITY"
  else
    printf '  %-46s %s\n' "$1" "DIVERGENCE"
    printf '    pipeline A (rsync+archive): %s\n' "$2"
    printf '    pipeline B (git-tar):        %s\n' "$3"
    failures=$((failures + 1))
  fi
}

# ---------------------------------------------------------------
# Method A: current pipeline (rsync worktree copy + git archive HEAD)
# ---------------------------------------------------------------
A_DIR="$WORK/method-a"
snapshot_copy_worktree "$PROJECT" "$A_DIR" 2> "$WORK/a-warnings" || { echo "FATAL: rsync copy failed" >&2; exit 2; }
git -C "$PROJECT" archive HEAD > "$WORK/baseline.tar"
# Worktree-side file list, relative paths, sorted; dirs excluded from the listing
a_list=$(cd "$A_DIR" && find . -mindepth 1 ! -type d | sed 's|^\./||' | sort)

# ---------------------------------------------------------------
# Method B: proposed tar-only (git-enumerated)
# ---------------------------------------------------------------
# Enumerate: tracked files still present in the worktree, plus untracked
# non-ignored files. Deleted-from-worktree tracked files are absent by construction.
# Enumerate: tracked files still present in the worktree, plus untracked
# non-ignored files. Deleted-from-worktree tracked files are absent by construction.
(  cd "$PROJECT"
  { git ls-files --cached -z; git ls-files --others --exclude-standard -z; } \
    | while IFS= read -r -d '' f; do [[ -e "$f" || -L "$f" ]] && printf '%s\0' "$f"; done
) | sort -z > "$WORK/b-input.z"
# Pack the enumerated list; use -T with NUL-delimited names, no recursion.
tar -C "$PROJECT" --null -T "$WORK/b-input.z" -cf "$WORK/method-b.tar"
# Extract and enumerate from the result -- `tar -tf` backslash-escapes non-ASCII
# names, so a raw listing comparison would report false divergences.
B_DIR="$WORK/method-b"
mkdir -p "$B_DIR"
tar -C "$B_DIR" -xf "$WORK/method-b.tar"
b_list=$(cd "$B_DIR" && find . -mindepth 1 ! -type d | sed 's|^\./||' | sort)

# ---------------------------------------------------------------
# Parity: worktree-side A vs B
# ---------------------------------------------------------------
echo "== Discovery layer 1: file-list parity (worktree copy) =="
a_only=$(comm -23 <(echo "$a_list") <(echo "$b_list") || true)
b_only=$(comm -13 <(echo "$a_list") <(echo "$b_list") || true)
if [[ -z "$a_only" && -z "$b_only" ]]; then
  report "worktree file list: rsync vs git-tar" - - match
else
  report "worktree file list: rsync vs git-tar" "$a_only" "$b_only" diverge
fi

# Per-case expectations for B (the proposed method's semantics)
echo
echo "== Per-case semantics of the proposed git-enumerated tar =="
b_has() { grep -Fxq "$1" <<< "$b_list" && echo yes || echo no; }
report "c3  deleted tracked file absent from tar" "deleted.txt" "$(b_has src/deleted.txt)" \
  "$([[ $(b_has src/deleted.txt) == no ]] && echo match || echo diverge)"
report "c4  renamed tracked file: new name present" "renamed-moved.txt" "$(b_has src/renamed-moved.txt)" \
  "$([[ $(b_has src/renamed-moved.txt) == yes ]] && echo match || echo diverge)"
report "c6  nested .gitignore honored" "secret.txt" "$(b_has src/deep/secret.txt)" \
  "$([[ $(b_has src/deep/secret.txt) == no ]] && echo match || echo diverge)"
report "c7  root .gitignore honored (app.log)" - "$(b_has app.log)" \
  "$([[ $(b_has app.log) == no ]] && echo match || echo diverge)"
report "c8  global excludesFile honored" - "$(b_has globalonly.txt)" \
  "$([[ $(b_has globalonly.txt) == no ]] && echo match || echo diverge)"
report "c9  .git/info/exclude honored" - "$(b_has repoonly.txt)" \
  "$([[ $(b_has repoonly.txt) == no ]] && echo match || echo diverge)"
report "c10 negation: keep.debug kept" - "$(b_has keep.debug)" \
  "$([[ $(b_has keep.debug) == yes ]] && echo match || echo diverge)"
report "c10 negation: drop.debug dropped" - "$(b_has drop.debug)" \
  "$([[ $(b_has drop.debug) == no ]] && echo match || echo diverge)"
report "c13 empty dir in rsync copy" \
  "$([[ -d $A_DIR/emptydir ]] && echo present || echo absent)" \
  "$([[ -d $B_DIR/emptydir ]] && echo present || echo absent)" \
  "$([[ ! -d $B_DIR/emptydir ]] && echo note-empty-dir-only-in-rsync || echo diverge)"
report "c14 name with space survives" - "$(b_has 'has space.txt')" \
  "$([[ $(b_has 'has space.txt') == yes ]] && echo match || echo diverge)"
report "c14 unicode name survives" - "$(b_has 'unicode-é中.txt')" \
  "$([[ $(b_has 'unicode-é中.txt') == yes ]] && echo match || echo diverge)"
report "c15 binary content present" - "$(b_has binary.bin)" \
  "$([[ $(b_has binary.bin) == yes ]] && echo match || echo diverge)"
report "c11 symlink present" - "$(b_has src/link-to-committed)" \
  "$([[ $(b_has src/link-to-committed) == yes ]] && echo match || echo diverge)"

echo
echo "== Method A stderr (rsync global-exclusion warnings, informational) =="
cat "$WORK/a-warnings" || true

echo
if [[ "$failures" -eq 0 ]]; then
  echo "RESULT: parity across all cases"
  exit 0
else
  echo "RESULT: $failures divergence case(s) -- see report above"
  exit 1
fi
