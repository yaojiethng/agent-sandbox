---
name: communication-principle-show-dont-describe
description: "Hand over the artifact a reader acts on, or the output that proves a rule was followed, instead of a description or an assumption. Apply when writing an instruction, a prompt, a doc, a reply, or a comment."
---

# Show, Don't Describe

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

**The test.** Must the reader interpret, or can they copy? Where a rule applies, is there output that shows it was followed?
