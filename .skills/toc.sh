#!/usr/bin/env bash
# toc — print header outline of a markdown file with line numbers
# usage: toc <file.md>
# output: indent-by-level header map suitable for view_range targeting

if [[ -z "$1" ]]; then
  echo "usage: toc <file.md>" >&2
  exit 1
fi

grep -n "^#" "$1" | while IFS= read -r line; do
  lineno="${line%%:*}"
  header="${line#*:}"
  # count leading # chars for indent level
  level=$(echo "$header" | sed 's/[^#].*//' | tr -cd '#' | wc -c | tr -d ' ')
  indent=$(printf '%*s' $(( (level - 1) * 2 )) '')
  printf "%4s  %s%s\n" "$lineno" "$indent" "$header"
done
