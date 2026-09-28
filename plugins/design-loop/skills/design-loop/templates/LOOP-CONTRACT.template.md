# Loop contract — <EFFORT NAME>

<DATE> · v1 · Runtime: <RUNTIME>
Status: **DRAFT** — becomes binding only after `check-loop.sh` passes, the review
gate (Codex + fresh subagent) closes with no blocker, and <HUMAN> approves.

Plain words: this file is the loop's law. The tick prompt may be shorter than this
file, but nothing in it may contradict this file. Where an authoritative plan
exists, THAT plan stays authoritative for item content; this contract only governs
how the loop runs.

<!-- Fill every <PLACEHOLDER>. Placeholder grammar is strict — uppercase letters,
     digits, spaces, "_", "-" only (e.g. <WALL-CLOCK CEILING>) — because
     check-loop.sh detects exactly that shape. Put examples and guidance in these
     deletable comments, never inside a placeholder. Delete all comments before
     validating. Keep the section headers verbatim — check-loop.sh greps them.
     RUNTIME is one of: /loop dynamic | /goal | Workflow | /schedule. -->

## 1. Outcome (observable, with evidence)

<!-- An activity ("improve X", "work on Y") is not an outcome. Write a condition
     someone could check without trusting the loop's word.
     Evidence examples: "uv run pytest -q exit 0 at the stamped SHA", "report at
     eval/results/RUN-ID/report.html", "ledger shows landed for A-1..A-4". -->

- **Outcome:** For <INPUTS>, <BEHAVIOR> holds at <THRESHOLD>, while the §3
  invariants stay true.
- **Evidence that proves it** (each item named; none of them "the agent said so"):
  - <EVIDENCE COMMAND AND EXIT CODE>
  - <EVIDENCE REPORT PATH>
  - <EVIDENCE LEDGER STATES>
- **Checked by:** <CHECKER>
  <!-- e.g. "a fresh verifier subagent given this contract + the integrated diff
       directly (never the maker's summary)", a script, and/or a named human. -->

## 2. Scope and non-goals

- **May mutate:** repos <REPOS>, branches <BRANCHES>, files <FILE BOUNDS>.
- **Isolation:** <ISOLATION MODE>
  <!-- MANDATORY, exactly one of:
       "serialized (no worktrees)", OR
       "worktrees authorized by <DECISION ID>" — a reference into your team's
       recorded decision log. The validator rejects anything else. -->
- **Item source of authority:** <PLAN DOC> — batch tables and forecasts in any
  operational doc are NOT authority; eligibility is recomputed from the plan plus
  live gate states every tick.
- **Session capabilities:** <SESSION CAPABILITIES>
  <!-- What the human provides and keeps fresh, named per item: a live cloud
       SSO session, a VPN/tunnel to a dev or prod environment, an admin
       profile. The loop never re-auths itself; an expired capability mid-loop
       = the dependent item -> blocked, plus an ACTION packet naming the exact
       command the human should run to restore it. "none" is a valid fill. -->
- **Non-goals (explicitly out):** <NON-GOALS>

## 3. Invariants (true before, during, and after every tick)

- <INVARIANT LIST>
  <!-- e.g. existing endpoints byte-identical (contract tests green); suite green
       on the target branch after every land; no PHI in any fixture or log. -->
- **The measuring instrument is immutable to the loop:** no editing tests, eval
  criteria, DoD lines, or this contract. A change there is an
  agent-proposes-human-ratifies decision (§5), queued in the ledger.

## 4. Budgets

<!-- Every ceiling here must be computable from the ledger's Budget stanza by a
     fresh dispatcher with no memory — that is what makes it enforceable. -->

| Budget | Ceiling | On breach |
|---|---|---|
| Ticks | <TICK CEILING> | stop: BUDGET |
| Wall-clock | <WALL-CLOCK CEILING> | stop: BUDGET |
| Spend / tokens | <SPEND CEILING> | stop: BUDGET |
| Retries per item | <RETRY CEILING> | item → `blocked`, decision packet queued |
| Concurrent agents | <CONCURRENCY CEILING> | hold the excess, say so in the tick report |

- **No-progress rule:** <NO-PROGRESS TICKS> consecutive ticks with the same
  failure signature, or with zero ledger state transitions, → stop: NO-PROGRESS,
  queue a decision packet. Retrying an identical action a third time is
  prohibited.

## 5. Decision rights

<!-- Encode as ledger states, not reminders. Never remove standing human-only
     entries; add effort-specific rows to each class. The human answers decision
     packets in chat or on the ticket; the DISPATCHER transcribes the disposition
     into the ledger (single-writer rule).
     OUTWARD GRANT: by default ALL outward actions (Jira, Notion, Slack, email)
     are queued as proposals and batch-approved by the human. A contract may
     delegate a NAMED subset — scope it tightly: which project/space, which
     actions (comment / transition / create), which target states, a per-tick
     cap, and what stays forbidden regardless (Done-transitions, deletes,
     anything outside the effort's epic). Fill "none" for pure queue mode.
     If your tracker has format quirks (e.g. Jira: issue-CREATE descriptions
     take wiki markup while comments/updates take markdown), record them in
     the grant so the loop cannot relapse on them. -->

| Class | Decisions | Mechanism |
|---|---|---|
| **Agent-autonomous** | reversible implementation details inside settled bounds; <AUTONOMOUS EXTRAS> | act, log in the event log |
| **Agent proposes, human ratifies** | architecture and public contracts; eval criteria / DoD / test changes; scope changes; <RATIFY EXTRAS> | decision packet in the ledger queue; the affected item cannot pass <RATIFY HOLD STATE> until the dispatcher records the approval |
| **Delegable outward actions** | Jira comments / transitions / new tickets · Notion updates · other outward writes. Default: **queued as proposals** for batch approval by <HUMAN>. This effort's grant: <OUTWARD GRANT> | execute only inside the recorded grant, logging each executed action with a link; queue everything else |
| **Human-only (standing — your team)** | `git push` · deploy · infra apply (e.g. terraform) · credential re-auth · production data (never, even read) · secrets / `.env` (never read) · <STANDING EXTRAS> | loop stops at the boundary and queues |
| **Human-only (this effort)** | <HUMAN-ONLY EXTRAS> | as above |
  <!-- e.g. closing ticket MA-XXX; signing thresholds; the gate conversations. -->

## 6. Stop policy

**Tick outcomes (normal, loop continues):** `PROGRESS` — at least one ledger state
transition this tick · `WAITING` — in-flight work healthy, nothing else eligible.

**Terminal reasons (stop the loop; the report names which):**

1. **SUCCESS** — §1 evidence complete, all §7 gates satisfied at land time.
2. **HUMAN-GATE** — the next action consumes a reserved decision → write the
   decision packet, stop.
3. **BLOCKED** — a precondition, credential, environment, or external party is
   missing → name it, stop. Never work around it; never downgrade the DoD to
   something satisfiable; never fabricate the missing input.
4. **BUDGET** — any §4 ceiling reached, as computed from the ledger Budget stanza.
5. **NO-PROGRESS** — the §4 rule fired.

**Escalation format (the decision packet — written in plain words for a human
who has not been watching the loop):** never a bare codename. Open with a
one-line definition of the item ("A-5 — the amendment that changes rule 5's
prose") and 2–3 sentences of background a reader without loop context needs.
Then: the exact decision · why it is human-owned (cite the §5 row) · evidence
and current state · 2–3 options, each with its consequence in plain words and a
concrete example where it helps · the loop's recommendation · what remains
safely runnable while waiting · and **the literal reply the human can send**
(e.g. reply `adopt P-2` or `discard P-2`). Never an assumed default after a
timeout for human-only decisions.

## 7. Gates

<!-- Effect is MANDATORY, one of: blocks-dispatch | blocks-merge |
     allows-provisional-land | blocks-close. The tick branches on it:
     blocks-merge → done-awaiting-gate; allows-provisional-land → may merge,
     terminal state landed-provisional, no Done queued; blocks-close → ticket
     transition never queued while open. Gates are applied at dispatch, re-checked
     at land time, and re-checked once more immediately before the merge. -->

| Gate | Owner | Effect | What it blocks |
|---|---|---|---|
| <GATE ID> | <GATE OWNER> | <GATE EFFECT> | <GATE SCOPE> |

Gate conversations are human actions running alongside the loop — the loop waits
on their recorded state; it never performs or simulates them.

## 8. Before the first tick (launch checklist)

- [ ] Target repos have no uncommitted work in scope files (classify + commit the
      intended increment by explicit path first; no blanket commits, no plain
      stash). If a main checkout must stay dirty, integration happens on a
      temporary branch in a clean worktree — never by switching the dirty checkout.
- [ ] §2 Isolation line satisfied: serialized, OR the authorizing decision is
      recorded; worktrees sit beside their repo, search config excludes
      worktree patterns, lockfile install verified in each worktree.
- [ ] `LOOP-LEDGER.md` exists, filled from the template, lock stanza `unclaimed`.
- [ ] Readiness preconditions verified per item: <READINESS ITEMS>
      <!-- databases, ports, live sessions — missing = that item starts blocked,
           never improvised around. -->
- [ ] Reasoning effort chosen for the dispatcher session and set on the command line
      (claude --effort followed by the chosen level), including on every resume.
- [ ] `check-loop.sh` PASS on all three loop-pack files.
- [ ] Review gate closed: Codex + fresh subagent, no blocking finding.
- [ ] <HUMAN> approved this contract (this line initialed: ____).

## 9. Item contract (what every dispatched worker receives, in full)

<!-- The worker sees ONLY this brief — it cannot obey a boundary it was never
     given. The dispatcher pastes this section's content into every spawn. -->

1. **The plan row, quoted verbatim**, plus any settled-design override — where row
   and override disagree, the override wins and the discrepancy is reported,
   never silently resolved.
2. **The DoD as a checklist**, each line naming the evidence that satisfies it
   (a test name, a report path, a git SHA).
3. **Bounds:** owned files (and files it must not touch), whether it may start a
   server and on which port, its workspace path + branch + base SHA.
4. **Standing prohibitions, verbatim, every spawn:** no `git push` · no deploy ·
   no infra apply · no credential re-auth · no tracker/wiki/chat writes (Jira,
   Notion, Slack, email — report to the dispatcher; it queues or acts within
   its grant) · never read secrets / `.env` · never read production data · no
   self-merge · no worktree creation beyond the assigned workspace · no ledger
   writes · <STANDING EXTRAS>.
5. **First action: read the workspace-root `CLAUDE.md` and the target repo's
   `CLAUDE.md`** — repo-specific rules bind the worker even when this brief
   doesn't repeat them.
6. **Stop condition:** commit locally by explicit paths, report done to the
   dispatcher with evidence, then stop.
