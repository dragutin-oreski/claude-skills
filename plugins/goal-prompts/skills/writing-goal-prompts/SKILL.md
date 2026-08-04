---
name: writing-goal-prompts
description: Write a resumable prompt for Claude Code's /goal command. Use when asked to "write a goal prompt", "create a /goal", "author a goal/effort prompt", "set up a resumable long-running goal", or "make a goal that survives interruption". Bakes in the 4000-char limit, file-based progress + resumability, ultrathink, subagent delegation, and the adversarial review gate so you don't retype them.
---

# Writing /goal prompts

`/goal <condition>` makes Claude Code keep working across turns until a completion
condition holds; after each turn a small/fast model checks the condition and, if unmet,
starts another turn. This skill produces a **good** goal prompt: one that is resumable,
stays under the limit, and defines a completion condition the evaluator can actually check.

The deliverable is a `GOAL.md` file (the text you paste after `/goal`), usually plus a
`PROGRESS.md` the goal creates on first run — and for large efforts a `PLAYBOOK.md` +
`BRIEF.md`. Fill the templates in this skill's `templates/` directory, then validate
with its `check-goal.sh`.

## The four mechanics that dictate the design

Everything below exists because of how `/goal` actually works. Do not skip these:

1. **The argument is BOTH the directive and the completion condition.** Setting a goal
   starts a turn immediately with the condition as the directive. Write it as an
   instruction *and* a testable end state.
2. **The evaluator sees only the transcript.** A small/fast model (Haiku by default)
   judges the condition each turn; it **cannot run tools or read files**. So the goal must
   make Claude *surface* progress in its turn output (print the checklist), and the DONE
   condition must be provable from what Claude said — not from files the evaluator can't see.
3. **Resume resets the turn counter and may start fresh context.** A goal restored via
   `--resume` loses its timer/turn count, and re-pasting the goal in a new session has no
   memory. Therefore **durable state MUST live in files on disk** — the goal reads
   `PROGRESS.md` first and continues from it. This is the only thing that makes
   "re-send the same goal to continue" real instead of "restart from scratch".
4. **Hard 4000-character limit.** Keep detail out of the condition; push it into
   `PLAYBOOK.md`/`BRIEF.md` that the goal reads. Multibyte chars (— → ×) cost 3 bytes each,
   so prefer ASCII to stay byte-safe too.

## Workflow

1. **Copy the template** from this skill's directory into your working state dir:
   `cp <this-skill-dir>/templates/GOAL.template.md <STATE-DIR>/GOAL.md`
2. **Fill every `<PLACEHOLDER>`** and delete the guidance comments. The fixed scaffolding
   (resumability protocol, method, review gate, end-of-turn surfacing, turn cap) is already
   written — you only supply the goal, boundaries, deliverables, and DONE condition.
3. **For a large effort**, also fill `PLAYBOOK.template.md` (detailed spec) and write a
   `BRIEF.md` of grounded facts, so the 4000-char condition can stay lean.
4. **Validate** — this is the primary check, run it every time:
   ```bash
   bash <this-skill-dir>/check-goal.sh <STATE-DIR>/GOAL.md
   ```
   It reports character + byte count vs 4000, flags non-ASCII, and greps for the required
   elements (progress-file-first, resume/continue, turn counter, end-of-turn surfacing,
   DONE-WHEN, subagents, evidence, boundaries). Fix every FAIL; review the WARNs.
5. **Review** (the user usually wants this): have a second model review it adversarially —
   e.g. Codex via the `calling-codex` skill (shipped alongside this one) — and optionally
   a fresh subagent. Apply the findings, then re-validate.
6. **Run it:** `/goal <paste the contents of GOAL.md>`. Pair with auto mode so each turn
   runs unattended. **To resume after any stop, send the same `/goal` text again.**

## What the template bakes in (so you stop retyping it)

- **Resumability contract** — read `PROGRESS.md` first; resume from the first unchecked
  item; read existing deliverables before editing; "must CONTINUE, never restart";
  idempotent increments; append evidence + tick + increment the cumulative turn counter.
- **`ultrathink`** — a real Claude Code thinking trigger; kept in the condition so it fires
  each turn.
- **Subagent delegation** — delegate independent work, keep working while they run, cheaper
  models for grunt work, keep orchestrator context lean; a fresh verifier subagent every ~N phases.
- **No fabrication** — ground every claim in a tool result; say so when unverified.
- **Autonomy + no early stop** — proceed on reversible actions; pause only for genuinely
  user-only decisions; don't end a turn on a promise.
- **Transcript-checkable completion** — end-of-turn checklist surfacing; a cumulative turn
  counter in `PROGRESS.md` so the turn cap survives resumes; a DONE-WHEN provable from the turn.
- **Review gate** — a second model (full access) + a fresh subagent, findings resolved in `REVIEW.md`.

## Gotchas

- **A turn cap of "stop after N turns" is unenforceable as-is** — the counter resets on
  resume and the model has no turn count. The template puts a *cumulative* counter in
  `PROGRESS.md` and phrases the cap against it. Keep it that way.
- **"All deliverables non-stub" is not transcript-checkable** unless Claude prints
  per-deliverable evidence (path + section headings) on the final turn. The template does this.
- **Don't tell the goal to echo its reasoning** as response text — on some models that
  triggers a reasoning-extraction refusal. Surface *progress*, not *thinking*.
- **`check-goal.sh` is heuristic** — it confirms presence via grep, not quality. A PASS means
  "the scaffolding is there and it fits", not "the goal is well-scoped". Read it yourself too.
- **`wc -m` counts characters, `wc -c` counts bytes.** The script strips one trailing newline
  before counting because the pasted `/goal` argument has none.

## Files

- `check-goal.sh` — the validator (primary path). Exit 0 = ok/warn, 1 = has blockers, 2 = usage/input error. It FAILs if any `<placeholder>` or `<!-- comment -->` remains, so run it on your *filled* `GOAL.md`, not the raw template.
- `templates/GOAL.template.md` — the goal condition; fill placeholders, keep <=4000 chars.
- `templates/PROGRESS.template.md` — the on-disk state file (created on first run).
- `templates/PLAYBOOK.template.md` — detailed spec for large efforts (optional).
