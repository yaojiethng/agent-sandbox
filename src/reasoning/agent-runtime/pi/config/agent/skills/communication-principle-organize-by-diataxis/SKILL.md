---
name: communication-principle-organize-by-diataxis
description: "Apply when adding to documentation or tidying it: name the Diataxis mode each unit serves, tutorial, how-to, reference or explanation, then file it under that mode and link the seam, and move what serves another need."
metadata:
  intent: "Organizing documents and contents according to the Diataxis mode, not conflating the technical concerns."
  mechanism: "Name the Diataxis mode each unit serves, then file it under that mode, link the seam, and move what serves another need."
  leitwort: diataxis
  neighbours: []
---

# Organize documentation by mode

Every unit of content, a span whose parts serve one central meaning, carries one Diataxis mode, and the mode is the need it serves in that place.

**The pattern.**

Two questions pick the mode. Does the content inform action or understanding, and does it serve learning or work?

| Mode | The need | The character |
|---|---|---|
| tutorial | learning by doing | a lesson that leads a beginner to a first success |
| how-to | doing a job | steps to a goal, with no teaching and no background |
| reference | looking something up | facts only, dry and complete, mirroring the thing described |
| explanation | understanding why | one bounded topic, with its context and its alternatives |

The questions run on the unit, not on the file. A unit that answers two needs is two units.

**Why.** One mode per unit is what makes documentation findable. A reader arrives with one need, and a unit that answers it lets them stop; a unit that answers two makes each reader carry the other's content. The mode names the need, so the fit is checkable at any grain.

**The unit.** A meaning unit (Graneheim and Lundman, 2004) may be a sentence, a paragraph, a section or a document. Units compose into larger ones, and the same test applies at each grain.

**What it does not cover.** Which copy of a subject owns it: [`principle-single-source-of-truth`](../principle-single-source-of-truth/SKILL.md). Whether a unit that serves its mode still carries prose about itself: [`communication-principle-cut-metadiscourse`](../communication-principle-cut-metadiscourse/SKILL.md).

**The test.** Name the unit's central meaning and the need it serves. Name the mode that answers the need, then check that every part serves that one meaning. A part that serves another is its own unit, and it belongs where its mode lives. Apply the test to one unit at a time.
