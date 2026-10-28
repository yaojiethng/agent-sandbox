# The exemplar

The first file of a close read, as presented on 2026-09-24, the turn the operator called the format to keep. It is trimmed to the beats the skill states and nothing else is invented: the fragments, the glosses and the limits are the ones the read produced.

## The opening

> You're right - let me present the actual reading material. Starting with the first file: the subject source, annotated, then each test in BDD terms.

The opening states what is being handed over and in what order. It carries no preamble, no restatement of the task and no plan for the rest of the run.

## The contract and the first function

> The file's purpose, from its header: the single loader for simple `KEY=VALUE` env files (the per-sandbox `.env`). Its two consumers are the Makefile `-include` (make variables) and the runtime export.

> **Missing-file guard**
>
> ```bash
>   [[ -f "$FILE" ]] || return 0
> ```
>
> A non-existent file is a silent success. The function reports success and sets nothing. (The header says the caller checks existence, but the function guards too.)

The fragment comes first so the reader can check the description against the code. The gloss states the silent behaviour, which is the part a reader cannot see from the name, and then the limit: the header and the function disagree about who guards, and the parenthesis is where that lands.

## One unit

> **`test_env_load_exports_valid_line`**
>
> - Given a `.env` file containing `FOO=bar`
> - When `env_load` is called on it
> - Then `FOO` holds `bar`
>
> What it is supposed to test: the happy path - one simple assignment reaches the environment. (It reads `FOO` back in the same shell, so it proves the value is set, not that it is exported to a child process.)

Given, When and Then are the preconditions, the invariant under test and the postcondition. The second paragraph says what the unit is for, and the parenthesis says what the unit does not establish. That parenthesis is the whole reason the reader can trust the rest.

## The close

> Three things I noticed while preparing this, for the findings log:
>
> 1. `_self_env_dir` is assigned and never used in this file.
> 2. No test asserts that comment lines are warning-free (the comment skip has no dedicated bite).
> 3. No test asserts that a loaded value is actually exported to a child process; the checks read it back in the same shell.
>
> Questions?

Findings last, numbered, three of them, and the turn ends on an open question rather than a summary. Each finding names the file and the behaviour, none of them proposes a fix, and the register is where they went.
