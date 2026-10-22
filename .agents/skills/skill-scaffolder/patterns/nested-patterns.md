# Nested pattern files

Open this when you write a skill and its body would carry more than one kind of content: a judgement, a code-bearing pattern, a fill-in form, or long background. A skill is a `SKILL.md` plus the siblings it names; the loader reads the `SKILL.md` and opens a sibling only when the task matches. Split so the reader meets the part the situation calls for, and keep the `SKILL.md` an index rather than a catalogue.

## The index

When the skill grows a sibling, add one row to the `SKILL.md` index naming the file and the situation that opens it. The index is the dispatch: a sibling the index does not name is a file nothing loads. State the situation in the reader's words, not the file's contents.

## What stays inline

Keep a **judgement** inline when it is short and states a quality with no cheap observer: one sentence of the standard and one of why. Keep the skill's **name and description** in frontmatter and the **operation** it performs in the body. Keep a **rule** the skill itself enforces inline, beside the step that applies it.

## What becomes a sibling

| Sibling | Holds | Form |
|---|---|---|
| `patterns/<subject>.md` | a **pattern**: "when you see X, instead do Y", especially for a mechanical task | the concrete code or form |
| `assets/<name>.<ext>` | a **fill-in form** an author copies | the template file |
| `references/<subject>.md` | **long background** the reader consults rather than applies | prose and examples |

A **convention**, criteria in prose with remediation for the negative case, stays inline unless it is long enough to need its own file; then it goes to `references/`.

## The size floor

When the body is short, do not split. Four one-line judgements do not need four files, and one code snippet does not need a directory. A sibling earns its file by the length of the form or example it carries, or by a situation a reader can name. A file that holds one line is a directory entry, not a dispatch.

## One home per thing

When a rule moves to a gate or a procedure, state it there and keep the skill's line to a pointer. Do not state it twice. The skill is the reader's meeting point, not the rule's only possible home.

## Naming and lint

Name a pattern file for its subject (`fixtures.md`, `assertions.md`), not for its form. A sibling is Markdown: the ASCII, one-paragraph-per-line and link gates read it. The document-shape gate reads the `SKILL.md` frontmatter and the principle shape; it does not read a sibling, so a sibling carries no frontmatter and no six-part shape.

## Worked example

The `testing` convention grew past one body into [`../../testing/SKILL.md`](../../testing/SKILL.md): four judgements inline, an index table, four pattern files under `patterns/`, and a fill-in template under `assets/`. The pattern files carry the code; the `SKILL.md` names each file by the situation that opens it.
