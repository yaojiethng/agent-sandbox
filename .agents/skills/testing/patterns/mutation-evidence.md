# Mutation evidence patterns

Open this when an instrument edits production code to test whether a unit catches the edit, and when a survivor or a proof verdict is about to be believed.

A mutation is evidence only if it changed the behaviour the suite reads. Each pattern below is a way an instrument reports a result about itself instead of about the code under test.

1. Confirm the mutant differs from its backup, and that the line that changed is the site the verdict depends on. Print the mutant's diff and read which line moved. A matcher given a repeated line can hit the other copy, and the indentation that told the two apart is invisible in a listing. A survivor is evidence about the line you actually changed.

2. A disabled guard has to be shown to fail. A condition can stay true by construction, so the branch the instrument believes it removed still runs and the run reports a survivor against unchanged code. Disable the condition with a form that aborts, and run the disabled state once to see the failure before trusting anything the instrument says about it.

3. A line whose deletion changes no outcome is a code row, not a coverage row. Classify by deleting the line and comparing what the callers do, never by arguing that a guard must matter. Where a guard repeats a check the runtime already makes, no input can distinguish the two, so no unit can fail on it: that is the line's verdict, and a source-text assertion written in its place pins the text rather than the behaviour.

4. Read the wall time. An instrument that replays suites finishes faster than the suites it names, so a run reporting every row as a survivor in seconds has measured the harness rather than the code. Two harness failures reach the same shape: a child runner that exits 0 without running its file, and a migration that silently matched nothing. Before a verdict leaves the instrument, prove the work happened. A verdict read from the exit status alone is not evidence either way: a run that failed needs the failing file's name, and one re-run, before either a survivor or a proof is believed, because a neighbouring gate can abort the whole run and read as the mutant.

5. Pass a mutation literal through the environment, never through the pattern. A perl program reads `$NAME` inside `\Q...\E` as its own variable, so a pattern built from a shell variable expands to nothing, matches nothing, and reports the file it never edited as a survivor: twenty of twenty-two bites no-op'd that way in one sweep. `OLD=... perl -0777 -pi -e 's/\Q$ENV{OLD}\E/.../'` passes the text as data. The same quoting also stops `\n` from being a line break, so a literal that spans lines takes `$'---\n### '` or an editor's `oldText`, which carries the newline itself.
