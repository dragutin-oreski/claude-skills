# The tick prompt — <EFFORT NAME>

<!-- The fenced block below is what the human pastes after /loop. Keep it
     self-contained: a fresh session with no memory of this design work must be
     able to run a tick from it plus the two files it names — both of which MUST
     exist before launch (contract §8). Omit the interval — dynamic pacing: ticks
     fire when tracked work finishes; the schedule is only the safety net for a
     hung agent.
     <REVIEW MECHANISM> worked example: "a fresh Codex session per the
     calling-codex skill (sandbox=danger-full-access, approval-policy=never),
     findings folded until no blocker".
     Size: /goal hard-caps at 4000 chars; /loop has no verified cap (a
     production block ran ~4100) but long blocks dilute — the validator warns
     past 4000 chars/bytes.
     Keep item-specific rules in the contract and cite them here by section. -->

```
/loop <EFFORT NAME> loop. One tick = advance the effort by one bounded increment,
then stop.

Read <PACK PATH>/LOOP-CONTRACT.md (the law) and <PACK PATH>/LOOP-LEDGER.md (the
state). Both exist; if either is missing, stop and report — never create or
improvise them. Claim the ledger lock per its lease rules: unclaimed or expired
-> claim, re-read to confirm, log the takeover; fresh lock from another session
-> exit, never co-dispatch; in doubt -> exit. <PLAN DOC> stays authoritative for
item content; any batch table is a FORECAST — eligibility is recomputed every
tick from the plan plus current gate states, and the contract's contention rules
override any concurrency column.

Each tick, in this exact order:
1. RECONCILE. Compare the ledger against the live agent registry and git.
   In-flight with agent gone = stale (contract stale rule: inspect the diff,
   then resume OR re-dispatch, never both). "dispatching" with no agent id =
   failed dispatch: re-reserve and re-spawn — an orphan workspace with
   uncommitted or unmerged work is QUARANTINED behind a decision packet, never
   deleted; reuse it only if provably empty.
2. CHECK completions. Worker reports done -> write done-reported, then the land
   protocol: re-check gates NOW at land time (dispatch-time eligibility is
   stale) and apply each gate's Effect from contract §7 (blocks-merge ->
   done-awaiting-gate; allows-provisional-land -> may merge, terminal
   landed-provisional, no Done queued; named sign-off outstanding ->
   ready-to-merge, held). Then: full suite where the work lives -> merge the
   target branch INTO the item's branch, re-run the suite -> adversarial review
   of the INTEGRATED branch by <REVIEW MECHANISM> — findings fold by
   re-dispatching the implementer; the dispatcher never edits code -> re-check
   gates + target SHA immediately before merging (target moved -> re-integrate,
   re-test) -> merge -> suite once more on the target -> terminal state per the
   contract -> remove the worktree if one was authorized -> outward actions:
   execute only inside contract §5's recorded grant, log each with a link;
   QUEUE the rest for <HUMAN> in plain words — never execute outward actions
   beyond the grant. Log land progress (suite / integrated / reviewed) as
   you go.
   <ITEM-SPECIFIC TERMINAL RULES>
3. RECOMPUTE eligibility (plan orderings + gate states + contention rules). Two
   eligible items claiming one owned file -> dispatch one, hold the other, say
   so.
4. DISPATCH each eligible, un-flighted item: write "dispatching <item>" to the
   ledger FIRST, then prepare its workspace per the contract's Isolation line,
   then spawn ONE implementer with the contract's §9 item contract in full —
   plan row verbatim plus overrides (disagreements reported, never silently
   resolved), DoD checklist with evidence names, bounds, the standing
   prohibitions verbatim, and the order to read the workspace-root CLAUDE.md
   and the target repo's CLAUDE.md before the first edit.
5. LOG. Update the Budget stanza (ticks used, no-progress streak, spend), write
   one dated event-log line for the tick plus one per item touched (agent id,
   workspace, branch, base SHA, contract version), refresh the lock heartbeat,
   and STOP. You are the dispatcher — do no implementation work yourself.

Name every tick's outcome: PROGRESS or WAITING (loop continues), or a terminal
stop from contract §6: SUCCESS · HUMAN-GATE (decision packet queued) · BLOCKED
(missing precondition named — never worked around, never a downgraded DoD) ·
BUDGET (computed from the Budget stanza) · NO-PROGRESS (never retry an identical
action a third time).

If a contract §8 launch precondition is unmet, stop and report it — do not work
around it. Gate conversations are human actions running alongside — never treat
a tick as one. Report each tick in <= 10 lines: outcome, dispatched / landed /
awaiting-gate / blocked / decisions queued, budget consumed, and what the next
tick expects.
```

## Runtime adaptations

- **`/goal` instead of `/loop`:** use the `writing-goal-prompts` skill — its
  template already carries the resumability contract, the 4000-char limit, and the
  transcript-checkable DONE. Bring this file's tick order and stop reasons into
  its METHOD section; the contract and ledger stay as-is and are validated with
  `check-loop.sh --runtime goal CONTRACT LEDGER`.
- **Workflow instead of an agent dispatcher:** when eligibility never needs
  interpretation (fixed item list, no human gates mid-flight), move steps 3–4 into
  a deterministic script: `pipeline(items, implement, verify)` with the §9 item
  contract in each prompt. Keep the ledger as the script's return artifact.
  Needs the user's explicit opt-in to multi-agent orchestration. Validate with
  `--runtime workflow`.
- **`/schedule` (cloud):** only for observation/maintenance loops that mutate
  nothing; interactively-authenticated MCP servers may be absent headless — verify
  reachability before scheduling. Validate with `--runtime schedule`.
