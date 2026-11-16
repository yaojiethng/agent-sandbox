---- MODULE ChangeModel ----
EXTENDS Naturals, TLC

VARIABLES state, head, lane

vars == <<state, head, lane>>

TypeOK ==
  /\ state \in {"working", "ready", "drafted", "accepted", "deleted"}
  /\ head \in Nat
  /\ lane \in {"agent", "host"}

Init ==
  /\ state = "working"
  /\ head = 0
  /\ lane = "agent"

Prepare ==
  /\ state = "working"
  /\ state' = "ready"
  /\ lane' = "agent"
  /\ UNCHANGED head

HistoryCleanup ==
  /\ state = "ready"
  /\ state' = "ready"
  /\ lane' = "agent"
  /\ UNCHANGED head

Export ==
  /\ state = "ready"
  /\ state' = "ready"
  /\ lane' = "agent"
  /\ UNCHANGED head

Draft ==
  /\ state = "ready"
  /\ state' = "drafted"
  /\ lane' = "host"
  /\ UNCHANGED head

Review ==
  /\ state = "drafted"
  /\ state' = "drafted"
  /\ lane' = "host"
  /\ UNCHANGED head

Confirm ==
  /\ state = "drafted"
  /\ state' = "accepted"
  /\ head' = head + 1
  /\ lane' = "host"

Reject ==
  /\ state = "drafted"
  /\ state' = "ready"
  /\ lane' = "host"
  /\ UNCHANGED head

Apply ==
  /\ state = "ready"
  /\ state' = "ready"
  /\ lane' = "host"
  /\ UNCHANGED head

HeadAdvances ==
  /\ state = "ready"
  /\ state' = "working"
  /\ head' = head + 1
  /\ lane' = "host"

OperatorGit ==
  /\ state = "drafted"
  /\ state' = "drafted"
  /\ lane' = "host"
  /\ UNCHANGED head

RejectAndRedraft ==
  /\ state = "drafted"
  /\ state' = "drafted"
  /\ lane' = "host"
  /\ UNCHANGED head

Delete ==
  /\ state = "accepted"
  /\ state' = "deleted"
  /\ lane' = "host"
  /\ UNCHANGED head

AbandonWorking ==
  /\ state = "working"
  /\ state' = "deleted"
  /\ lane' = "host"
  /\ UNCHANGED head

AbandonReady ==
  /\ state = "ready"
  /\ state' = "deleted"
  /\ lane' = "host"
  /\ UNCHANGED head

Done ==
  /\ state = "deleted"
  /\ UNCHANGED vars

Next ==
  \/ Prepare \/ HistoryCleanup \/ Export \/ Draft \/ Review
  \/ Confirm \/ Reject \/ Apply \/ HeadAdvances
  \/ OperatorGit \/ RejectAndRedraft
  \/ Delete \/ AbandonWorking \/ AbandonReady \/ Done

Spec == Init /\ [][Next]_vars

StateConstraint == head <= 3

====
