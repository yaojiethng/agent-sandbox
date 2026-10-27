# Argument patterns

Open this when code builds a command line, or when a flag and a value can be read as each other.

## p-20 Terminate flag parsing before a filename

```bash
cp --parents -- "$file" "$DEST/"
rm -- "$file"
```

Most tools read an argument beginning with `-` as a flag, and a filename is an argument, so a file named `-rf` is a deletion. `--` terminates flag parsing at the first filename.

Replaces: `cp --parents "$file" "$DEST/"` and `rm "$file"`, where the name comes from a directory listing.

## p-42 Put options before positional arguments

```bash
# Wrong: an option after the positional arguments is refused, and nothing is written
git bundle create "$bundle" "$rev" -q

# Right
git bundle create -q "$bundle" "$rev"
```

A git subcommand reads its options before its positional arguments, and refuses an option that comes after them as an unrecognized argument. Nothing is produced and the refusal is easy to lose: when the call is behind a guard or an `if`, the run reads as complete without the artefact it exists to make. Put every option first, and check that the artefact exists rather than that the call returned.

Replaces: `git bundle create <file> <rev> -q`, whose only trace was the missing bundle.

## p-47 Reject an argument where it enters, saying what was expected

```bash
MODE="${1:-}"
case "$MODE" in
  build|test|release) ;;
  *) printf 'usage: %s build|test|release\n' "$0" >&2; exit 1 ;;
esac
```

A value validated only where it is used fails late, after the work that came before it, and the message names the internal consumer rather than the argument the operator passed. Check it once, at the boundary where it arrives, and print the accepted values: the usage line is the only place the operator learns what the command takes.

Replaces: a `case` with a `*)` branch that falls through, and a required value checked three functions below where it was parsed.
