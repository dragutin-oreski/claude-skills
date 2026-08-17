---
name: design-loop
description: Design (never run) an engineered loop for long-running agent work — the loop contract, ledger schema, decision-rights table, stop policy, and tick prompt, plus runtime selection (/loop, /goal, Workflow, schedule). Use when asked to "design a loop", "set up a dispatcher/batch loop", "author a loop contract", "put agents on a loop", "design how to run something autonomously until done", or anything "loop engineering". Encodes hard-won dispatcher lessons (reserve-first ledger, gates re-checked at land time, integrate-then-retest, review-before-merge) so they are not re-learned per effort.
---

# Designing loops

Extracted from a production multi-repo batch loop on a clinical health platform,
hardened by two independent adversarial reviews (Codex + a fresh Claude subagent;
five blockers found and folded), and trimmed to current skill guidance:
principles here, mechanics in the templates.

**Plain words.** A *loop* is a system that prompts an agent for you: act → observe
→ verify → decide (continue / stop / ask the human). A *tick* is one turn of that
cycle; the *dispatcher* runs the tick and spawns *workers* to build things. The
*ledger* is the on-disk state file — the source of truth, because agent context is
lost between ticks. A *gate* is a named human decision the loop waits on. A *DoD*
(Definition of Done) is a checklist where each line names its evidence. A
*maker/checker split*: whoever builds a thing never judges it. The *loop contract*
defines the outcome, the bounds, and who decides what.

**This skill designs loops; it never runs them.** The deliverable is a **loop
pack** of three files in the effort's docs directory, filled from `templates/`
(each template's comments explain its fields — don't restate them elsewhere):

| File | What it is |
|---|---|
| `LOOP-CONTRACT.md` | the loop's law: outcome + evidence, scope + isolation, invariants, budgets, decision rights, stop policy, gates with effects, launch checklist, §9 worker briefing |
| `LOOP-LEDGER.md` | the state: lease lock (ships `unclaimed` — first tick claims it), budget stanza, item states, decision queue, event log. Shipped filled at design time, never "created later" |
| `LOOP-PROMPT.md` | the tick prompt pasted after `/loop` |

## Two principles everything follows from

1. **The ledger, not any agent, holds the truth.** Every tick reconciles it
   against reality (live agents, git). The dispatcher must be replaceable
   mid-effort with zero loss — if losing its context loses state, the state was in
   the wrong place. No long-lived "super-agent" whose summaries are the record.
2. **Deterministic rules own bookkeeping; agents own judgment.** Stable things
   (state transitions, required evidence, who approves what) are written down and
   mechanically checked; agent judgment is spent only where interpretation is
   genuinely needed.

## Workflow

**1. Pick the runtime** by uncertainty, risk, parallelism, duration:

| Work shape | Runtime |
|---|---|
| Exploratory, sequential, judgment-heavy | `/goal` — author via the `writing-goal-prompts` skill; contract + ledger still apply (`--runtime goal`) |
| Dispatcher over a batch with changing eligibility/gates | `/loop`, dynamic pacing + ledger — this skill's main target |
| Stable fan-out/fan-in, no judgment between stages | `Workflow` script (user opt-in required; `--runtime workflow`) |
| Periodic observation, no repo mutation | `/schedule` cloud routine (`--runtime schedule`) |
| Any of these with high-risk or semantic results | + maker/checker split and an adversarial review gate |

For `/loop`, always omit the interval (dynamic pacing): finished subagents
re-invoke the loop; the schedule is only the hung-agent safety net. Corollary: the
dispatcher lock's staleness is **wall-clock**, never "ticks".

Parallel workers in one repo need worktrees. If your team restricts worktrees (or
any isolation mechanism), the contract's mandatory Isolation line records either
`serialized` or the decision reference that authorizes them — never assume.

**2. Fill the contract.** The principles behind its sections:

- An outcome is a *condition with named evidence*, checked by something that is
  not the maker — never an activity ("improve X") and never the maker's own
  claim. Wire in real feedback signals: a test suite, a trace-store check that
  the implemented path actually ran, a judged eval run with a script-generated
  report, CI on the integrated branch.
- The measuring instrument (tests, eval criteria, DoD, the contract itself) is
  immutable to the loop; changing it is a human-ratified decision.
- Decision rights are ledger states, not reminders, in **four classes**:
  agent-autonomous · agent-proposes-human-ratifies · **delegable outward actions**
  (tracker/wiki writes — default: queued as proposals for batch approval; a
  contract may record a tightly scoped grant, e.g. "comment + transition tickets
  inside this epic, never close, never delete") · human-only standing (push,
  deploy, infra changes, credential re-auth, production data, secrets — your
  team's list, never removed, only extended).
- Declare **session capabilities** — human-provided, human-refreshed access the
  loop depends on (cloud SSO sessions, tunnels, admin profiles). Expiry mid-loop
  = item blocked + an action packet naming the exact command to run; the loop
  never re-auths itself.
- Every gate carries a typed effect the tick branches on (`blocks-dispatch`,
  `blocks-merge`, `allows-provisional-land`, `blocks-close`); gates are
  re-checked at land time and once more immediately before the merge, because
  eligibility rots.
- Budgets exist only if a fresh dispatcher can compute them from the ledger.
- Ticks end PROGRESS or WAITING; the loop stops only for SUCCESS · HUMAN-GATE ·
  BLOCKED · BUDGET · NO-PROGRESS. Blocked = name the missing thing and stop —
  never work around it, never downgrade the DoD.
- Escalation is a decision packet **written in plain words** for a human who has
  not been watching the loop: never a bare codename — a one-line definition of
  the item, background, options with consequences and an example, a
  recommendation, and the literal reply to send (`adopt P-2` / `discard P-2`).
  The human answers in chat; the dispatcher transcribes — one ledger writer.
- §9 is the worker's complete brief, standing prohibitions verbatim plus the
  order to read the project instruction files (CLAUDE.md) first — a worker
  cannot obey a boundary it was never given.

**3. Fill the ledger** (ships with the pack, lock `unclaimed`). Its load-bearing
rules: wall-clock lease with an explicit claim protocol ("in doubt → exit");
reserve-first dispatch; dirty orphan workspaces quarantined behind a decision
packet, never deleted; budget stanza updated every tick; terminal states richer
than done/not-done (`landed-provisional`, `done-awaiting-gate`, `ready-to-merge`,
`ready-to-land`) because "merged" never means "complete" while a gate is open, and
partial items never close their ticket.

**4. Fill the tick prompt.** Fixed order: claim lease → RECONCILE → CHECK
completions (land protocol, gate effects) → RECOMPUTE eligibility (plan is
authority, batch tables are forecasts) → DISPATCH (reserve-first, §9 brief) → LOG
+ STOP. The dispatcher never implements or edits code — review findings fold by
re-dispatching the implementer — and the merge-time adversarial review must name
its mechanism (`<REVIEW MECHANISM>`; unnamed collapses into self-review; the
`calling-codex` skill is a ready-made one).

**5. Validate, review, launch.**

```bash
bash check-loop.sh LOOP-CONTRACT.md LOOP-LEDGER.md LOOP-PROMPT.md   # /loop: all three
bash check-loop.sh --runtime goal LOOP-CONTRACT.md LOOP-LEDGER.md
python3 render_pack.py LOOP-CONTRACT.md LOOP-LEDGER.md LOOP-PROMPT.md -o pack-review.html
```

`render_pack.py` renders the pack to one styled review page (deterministic — no
model involved, so the render never drifts; the markdown stays the editable
source of truth). Fix every FAIL, read every WARN, then the review gate: an
adversarial review by an independent model/agent plus a fresh subagent; fold
until no blocker. Only then hand the human the `/loop <paste>` launch line with
the contract's §8 checklist.

## Gotchas

- **The validator checks presence, not meaning** — it cannot tell "never push"
  from "pushing is allowed". PASS = scaffolding present; the review gate is the
  semantic check.
- **Worktree placement can break path-based editable deps** (a package installed
  from a sibling directory): place worktrees beside their repo so relative paths
  still resolve, verify the lockfile install before handoff, remove the worktree
  after its branch lands, and exclude worktree patterns from your search config.
- **Evidence must come from the code under test:** a shared dev server serves the
  *main* checkout — workers run their own server from their workspace and stamp
  the tested git SHA into the evidence.
- **Integrate, then re-test:** two branches green in isolation prove nothing
  combined; merge target into item branch, re-run the suite there, review the
  *integrated* branch, only then touch the target.
- **Eligibility rots.** Anything computed at dispatch time (gates, sign-offs,
  contention, the target branch's head) is stale by land time. Re-check at the
  moment of consequence.
- **Uncommitted work in a target repo is a launch blocker:** worktrees branch
  from the commit, so it is invisible to workers. A checkout that must stay
  dirty integrates via a temporary branch in a clean worktree, never by
  switching.
- **The loop never substitutes for gate conversations** — it waits on their
  recorded state.
- **Tick-block size:** `/goal` hard-caps its argument at 4000 chars; `/loop` has
  no verified cap but long blocks dilute — the validator warns past 4000; keep
  item detail in the contract and cite sections.

## Files

- `templates/LOOP-CONTRACT.template.md`, `templates/LOOP-LEDGER.template.md`,
  `templates/TICK-PROMPT.template.md` — fill every `<PLACEHOLDER>` (strict
  grammar: uppercase/digits/space/`_`/`-`), delete the guidance comments.
- `check-loop.sh` — heuristic validator; exit 0 ok/warn, 1 blockers, 2 usage.
  `/loop` needs all three files; other runtimes validate contract + ledger.
- `render_pack.py` — deterministic markdown→HTML renderer for the filled pack
  (one review page: contract, ledger with color-coded states, tick block).
  Review in HTML, edit in markdown.

Companion skills in this marketplace: `writing-goal-prompts` (the `/goal`
runtime), `calling-codex` (a ready-made independent reviewer), `explain-diff`
(reviewing what a loop built).
