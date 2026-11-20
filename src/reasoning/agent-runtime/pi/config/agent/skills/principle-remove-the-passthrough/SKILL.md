---
name: principle-remove-the-passthrough
description: "Apply when a change adds a passthrough that only the next hop reads: a bridge document, a forwarding function or a staged commit."
metadata:
  intent: "A passthrough earns its place only through a consumer of its own, or a factor that pays for the write."
  mechanism: "Name the consumer that reads the passthrough for itself. If only the next hop reads it, remove the passthrough and let the producer write the final form."
  leitwort: passthrough
  neighbours:
    - communication-principle-cut-metadiscourse
    - principle-justify-materialization-cost
    - principle-propagation-discipline
---

# Remove the passthrough

A bridge document, a forwarding function and a staged commit act as passthroughs: each stands between a producer and the result its consumer reads, and none has a consumer of its own.

**The pattern.** Name the consumer that reads the artifact for itself. Where only the next hop reads it, the next hop can read the producer's output instead, and the passthrough copies that output with an extra step.

**Why.** Remove it before the next hop reads it. At scoping, it costs one deletion. Once the next hop reads it, the passthrough becomes a second source for the producer's output, every later change must reach both, and the copy drifts silently with nothing reporting it. The link collection adds one more cost: each new edge adds a place the next edit must visit.

**To remove.** A bridge that only lists links. A function that only calls its callee. A commit that only stages the next one.

**To keep.** A summary or an index that selects what its sources do not. A decorator, an adapter, a monad or a functional wrapper that adds a type or an effect. A commit or a branch that a later step consumes.

**The test.** Name the consumer that reads the artifact for itself. If only the next hop reads it, remove the passthrough and let the producer write the final form. A factor can pay for the write: a reader the next hop cannot serve, a cost the producer cannot avoid, a boundary the tree must keep. Name it, or remove the passthrough.

**Where another rule wins.** A passthrough with only one consumer is a second source you maintain without conferring any benefit, violating [`principle-single-source-of-truth`](../principle-single-source-of-truth/SKILL.md). Before any consumer reads it, no second source exists. [`communication-principle-cut-metadiscourse`](../communication-principle-cut-metadiscourse/SKILL.md) cuts a sentence that serves nothing. [`principle-justify-materialization-cost`](../principle-justify-materialization-cost/SKILL.md) owns the stored result with a consumer of its own.
