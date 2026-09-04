#!/usr/bin/env bash
# discovery_tar_roundtrip.sh -- Discovery layer 2: fidelity of the proposed
# git-enumerated tar method. Builds a tar from a fixture tree using the candidate
# mechanism (git ls-files enumeration -> `tar --null -T`), extracts it into a clean
# directory, and compares file list, content hashes, modes, and symlink targets
# against the source tree.
#
# Exit 0 = lossless round-trip; exit 1 = mismatches (report printed); exit 2 =
# infrastructure failure.
set -euo pipefail

WORK=$(mktemp -d /tmp/discovery-roundtrip.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

SRC="$WORK/source"
mkdir -p "$SRC/nested/deeper" "$SRC/emptydir"
git -C "$SRC" init --quiet
git -C "$SRC" config user.email discovery@sandbox
git -C "$SRC" config user.name discovery

echo plain > "$SRC/plain.txt"
printf '\x00\x01\x02\xff\xfe' > "$SRC/binary.bin"
echo deep > "$SRC/nested/deep.txt"
echo deeper > "$SRC/nested/deeper/leaf.txt"
echo x > "$SRC/nested/.hidden"
printf '*.ign\n' > "$SRC/.gitignore"
echo ignored > "$SRC/ignored.ign"
echo gone > "$SRC/doomed.txt"
git -C "$SRC" add .
git -C "$SRC" commit --quiet -m baseline
rm "$SRC/doomed.txt"
ln -sf plain.txt "$SRC/symlink"
ln -sf ../nested/deep.txt "$SRC/nested/relative-link"
chmod 740 "$SRC/plain.txt"
chmod 755 "$SRC/binary.bin"

# --- Build: git-enumerated tar ---
{ git -C "$SRC" ls-files --cached -z; git -C "$SRC" ls-files --others --exclude-standard -z; } \
  | while IFS= read -r -d '' f; do [[ -e "$SRC/$f" || -L "$SRC/$f" ]] && printf '%s\0' "$f"; done \
  | sort -z > "$WORK/list.z"
tar -C "$SRC" --null -T "$WORK/list.z" -cf "$WORK/out.tar"

# --- Extract into a clean directory (simulates the volume seed target) ---
DST="$WORK/extracted"
mkdir -p "$DST"
tar -C "$DST" -xf "$WORK/out.tar"

mismatches=0
fail() { printf 'MISMATCH: %s\n' "$1"; mismatches=$((mismatches + 1)); }

# --- File list (relative, files + symlinks) ---
# Comparison basis is the git-enumerated set: .git is never part of the pipeline,
# and ignored files must be absent (both sides).
src_list=$( { git -C "$SRC" ls-files --cached; git -C "$SRC" ls-files --others --exclude-standard; } \
  | while IFS= read -r f; do [[ -e "$SRC/$f" || -L "$SRC/$f" ]] && printf '%s\n' "$f"; done | sort)
dst_list=$(cd "$DST" && find . -mindepth 1 ! -type d | sed 's|^\./||' | sort)
if [[ "$src_list" != "$dst_list" ]]; then
  fail "file list"
  diff <(echo "$src_list") <(echo "$dst_list") || true
fi

# --- Content hashes ---
while IFS= read -r f; do
  s=$(sha256sum "$SRC/$f" | cut -d' ' -f1)
  d=$(sha256sum "$DST/$f" | cut -d' ' -f1)
  [[ "$s" == "$d" ]] || fail "content: $f"
done < <(echo "$src_list")

# --- Modes (exec/write bits; tar preserves mode bits directly) ---
while IFS= read -r f; do
  [[ -L "$SRC/$f" ]] && continue
  s=$(stat -c '%a' "$SRC/$f")
  d=$(stat -c '%a' "$DST/$f")
  [[ "$s" == "$d" ]] || fail "mode: $f ($s -> $d)"
done < <(echo "$src_list")

# --- Symlink targets ---
while IFS= read -r f; do
  [[ -L "$SRC/$f" ]] || continue
  s=$(readlink "$SRC/$f")
  d=$(readlink "$DST/$f")
  [[ "$s" == "$d" ]] || fail "symlink target: $f ($s -> $d)"
done < <(echo "$src_list")

# --- Empty directory behavior (expected: absent from tar; git cannot track it) ---
if [[ -d "$DST/emptydir" ]]; then
  echo "NOTE: empty directory present after extraction (tar included it)"
else
  echo "NOTE: empty directory absent after extraction (expected; git does not track empty dirs)"
fi

echo
if [[ "$mismatches" -eq 0 ]]; then
  echo "RESULT: round-trip lossless (list, hashes, modes, symlinks)"
  exit 0
else
  echo "RESULT: $mismatches mismatch(es)"
  exit 1
fi
