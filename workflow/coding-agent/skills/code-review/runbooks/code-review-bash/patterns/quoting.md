# Quoting patterns

Open this when code expands a variable, an array, or a command substitution into an argument list.

## p-7 Quote every expansion that can hold a path

```bash
cp -- "$file" "$dest"
"${array[@]}"
```

Unquoted expansion splits on whitespace, so a path with a space in it silently becomes two arguments. Quote at every point of use, and expand an array as `"${array[@]}"` rather than `$array` or `${array[*]}`.

Replaces: `cp $file $dest` and `"${array[*]}"`, both shellcheck SC2086.

## p-8 Emit per line, load into an array

```bash
list_files() { printf "%s\n" "src/libs" "docs/reference" "docs/adr"; }
mapfile -t SOURCES < <(list_files)
compute_hash "${SOURCES[@]}"
```

A string-as-list holds multiple paths in one scalar and works only while every value is whitespace-free; it breaks silently the first time one is not. Emit one item per line, load with `mapfile -t`, and expand as `"${SOURCES[@]}"`. A herestring with `read -ra` reads the first line only, so it is not a substitute.

Replaces: `compute_hash $(echo_and_split)` (SC2046) and `compute_hash $SOURCES` (SC2086).
