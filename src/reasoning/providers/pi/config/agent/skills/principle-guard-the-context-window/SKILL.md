---
name: principle-guard-the-context-window
description: "Apply when routing bulk work, planning a multi-file pass, or before stating how much room is left. Measure the window, route bulk out, and name the unit each pass counts."
disable-model-invocation: true
---

# Guard the context window

A capacity claim is a reading or an inference, and the reading comes from the window itself.

**The pattern.** Measure the room before you state it, route bulk work out of the main thread, and name the unit each pass counts.

- **Measure the room.** Run `bash "$HOME/.pi/agent/skills/principle-guard-the-context-window/context.sh"`. It prints the tokens used, the declared window, the percentage and the remainder, read from the provider's own usage in `$PI_SESSION_FILE`. Quote that reading whenever you state how much room is left.
- **Route bulk out.** Verbose output, screenshots and large documents go to a subagent. The main thread keeps the summary.
- **Keep hot content inline.** Text you read on every turn belongs in the skill file, not behind a `read` that pays for it again.
- **Name the unit of a pass.** Before a multi-file change, state the unit and the count, for example "20 files, one pass", and choose the count from the room the reading shows. A phase with no count cannot be checked against anything, by you or by a reader.

**Why.** Context overflow degrades reasoning quality, creates compression artifacts, and halts progress. A count nobody measured reads as capacity, so a pass sized by feel overruns the window and the work is lost rather than paused.

**The test.** Name the reading that supports the claim, and the unit and count the pass runs under. A capacity statement with no reading beside it is an inference, and it carries that label.
