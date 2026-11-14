---- MODULE ChangeModel ----
EXTENDS Naturals, TLC

VARIABLES state, head, lane

vars == <<state, head, lane>>

TypeOK ==
  /\ state \in {"notReady", "ready", "drafted", "accepted", "rejected", "applied"}
  /\ head \in Nat
  /\ lane \in {"agent", "host"}

Init ==
  /\ state = "notReady"
  /\ head = 0
  /\ lane = "agent"

Prepare ==
  /\ state = "notReady"
  /\ state' = "ready"
  /\ lane' = "agent"
  /\ UNCHANGED head

Draft ==
  /\ state = "ready"
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
  /\ state' = "rejected"
  /\ lane' = "host"
  /\ UNCHANGED head

Apply ==
  /\ state = "ready"
  /\ state' = "applied"
  /\ lane' = "host"
  /\ UNCHANGED head

HeadAdvances ==
  /\ state = "ready"
  /\ head' = head + 1
  /\ state' = "notReady"
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

Done ==
  /\ state \in {"accepted", "rejected", "applied"}
  /\ UNCHANGED vars

Next ==
  \/ Prepare \/ Draft \/ Confirm \/ Reject \/ Apply
  \/ HeadAdvances \/ OperatorGit \/ RejectAndRedraft \/ Done

Spec == Init /\ [][Next]_vars

StateConstraint == head <= 3

====
