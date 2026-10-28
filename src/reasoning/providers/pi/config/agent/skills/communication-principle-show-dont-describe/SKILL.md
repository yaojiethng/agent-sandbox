---
name: communication-principle-show-dont-describe
description: "Apply when a sentence asks the reader to interpret what you could have handed over: a template, a command, an example, or the output that proves a rule was followed."
---

# Show, don't describe

A description asks the reader to interpret. An artifact asks them to copy. Give the artifact.

**The pattern.** Replace the description with the thing itself.

| Instead of | Give |
|---|---|
| a table of sections and their descriptions | a template |
| prose describing how to call a library | a code example |
| prose describing a system | a diagram |
| a diagnosis that explains a failure | the command that avoids it |
| a rule stated in the abstract | the literal string to write |
| the roadmap write-back described | the rows to write back, listed |
| the commit-message rule stated | the commit message itself |
| a rule the reader is trusted to follow | the output that proves it was followed |

**Why.** An artifact cannot be misread. A command runs or it does not, so the meaning survives the writer. An assumption about compliance is not evidence; the output is.

**Fires on.** A description standing where an artifact would do, and an assumption that stands in for evidence.

**What it does not cover.** Whether the reader can open the artifact: `communication-principle-link-what-the-reader-can-open`. Whether the description should exist at all: `communication-principle-cut-what-carries-nothing`.

**The test.** Must the reader interpret, or can they copy? Where a rule applies, is there output that shows it was followed?
