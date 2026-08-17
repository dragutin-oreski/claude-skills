# Loop ledger — <EFFORT NAME>

**SOURCE OF TRUTH.** Only the dispatcher writes this file, and only one dispatcher
exists. Workers report to the dispatcher; humans answer decision packets in chat or
on the ticket; the dispatcher transcribes both — nobody else edits this file. If
this file and any agent's memory disagree, this file wins — after reconciling it
against the live agent registry and git, which win over everything.

<!-- Fill the <PLACEHOLDER>s and ship this file WITH the pack, lock unclaimed —
     the first tick claims it. Never leave ledger creation to the first tick.
     Keep the section headers verbatim — check-loop.sh greps them. -->

## Lock (wall-clock lease)

- state: **unclaimed**
- owning session: —
- heartbeat: —
- lease window: <LEASE MINUTES> minutes
  <!-- pick generously — e.g. 90; a tick that can run a full suite + review
       must fit inside it. Freshness is WALL-CLOCK, never "ticks": under dynamic
       pacing no tick interval exists. -->

Claim protocol: lock `unclaimed`, or heartbeat older than the lease window →
claim it (write state `claimed`, your session id, a fresh ISO timestamp), re-read
the stanza to confirm your claim stuck, and log the takeover in the event log.
Heartbeat within the lease window and not yours → **exit immediately, never
co-dispatch.** In doubt → exit. Refresh the heartbeat every tick, before STOP.

## Budget (updated every tick — contract §4 is enforced from here)

- started at: —
- ticks used: 0
- last tick at: —
- spend / tokens notes: —
- no-progress streak: 0 (consecutive ticks with zero state transitions)
- last state transition at: —

## States and transitions

`eligible → dispatching → in-flight → done-reported → { ready-to-merge |
done-awaiting-gate } → { landed | landed-provisional | ready-to-land }`
plus `blocked`, `stale`, and `quarantined` (reachable from any active state).

Definitions and rules:

- **Reserve-first:** `dispatching <item>` is written BEFORE the spawn. A
  `dispatching` row with no agent id = failed dispatch → next tick re-reserves
  and re-spawns. An orphan workspace found during recovery is **reused only if
  provably empty (no commits past base, no uncommitted changes); anything with
  uncommitted or unmerged work → `quarantined`: preserve the workspace and
  branch untouched, queue a decision packet. Never delete un-landed work.**
- **`done-reported`:** written by the dispatcher the moment a worker reports
  done, before the land protocol starts — so a tick dying mid-protocol knows the
  work exists. Land-protocol progress (suite passed → integrated → reviewed) is
  recorded as event-log lines for the same reason.
- **`stale`:** in-flight with agent gone, or no progress after <STALE TICKS>
  ticks → inspect the workspace diff, then explicitly `resume` OR `re-dispatch`.
  Never both.
- **`ready-to-merge`:** integrated suite green and adversarial review clean, but
  a named human sign-off from contract §7 is outstanding. Cannot advance without
  the dispatcher recording that sign-off.
- **`done-awaiting-gate`:** a gate with effect `blocks-merge` is open at land
  time — branch and workspace retained, nothing merged.
- **`landed`:** merged to the target branch, suite green there, review recorded,
  all sign-offs present.
- **`landed-provisional`:** merged so dependents can build while a gate with
  effect `allows-provisional-land` is open; semantics unfrozen; no Done
  recommendation queued; gate amendments reopen it.
- **`ready-to-land`:** everything done except a step only the human may execute
  (fast-forward, push). The loop stops there.
- **Partial items never close their ticket.** The Done recommendation is queued
  only when the item's full DoD — not the loop's slice of it — is met.

## Items

| Item | Ticket | State | Agent id | Workspace / branch | Base SHA | Heartbeat | Attempts | Evidence | Completion SHA |
|---|---|---|---|---|---|---|---|---|---|
| <ITEM ID> | <TICKET KEY> | eligible | — | — | — | — | 0 | — | — |

## Decision queue (the loop appends; the human answers in chat; the dispatcher records)

| # | Decision needed | Why human-owned (§5 row) | Evidence / current state | Options + consequences | Recommendation | Status / resolution |
|---|---|---|---|---|---|---|

Every row follows contract §6's plain-words packet format — a one-line
definition instead of a bare codename, background, options with consequences in
plain words, and the literal reply to send; Status / resolution records the
reply received.

Outward-action proposals (Jira/Notion/Slack) also live here with their evidence
links — queued for batch approval unless contract §5's recorded grant delegates
them, and every action executed under a grant is logged here with a link.

## Event log (append-only; one dated line per tick — even a WAITING tick — plus one per item event)

<!-- Dispatch lines record the contract version and plan revision the item was
     briefed under, so a later dispute can reconstruct what the worker was told. -->

- <DATE> tick 0 · ledger shipped with the pack; lock unclaimed.
