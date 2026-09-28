---
name: writing-goal-prompts
description: Write a resumable prompt for Claude Code's /goal command. Use when asked to "write a goal prompt", "create a /goal", "author a goal/effort prompt", "set up a resumable long-running goal", or "make a goal that survives interruption". Bakes in the 4000-char limit, file-based progress + resumability, a launch-time reasoning-effort choice, subagent delegation, and the adversarial review gate so you don't retype them.
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

## Reasoning effort is set at launch, not in the text

`/goal` has no effort parameter: every turn runs at the session's effort level. So the
level is a launch choice, recorded in `PROGRESS.md`, never a keyword in the goal text.

- **Launch:** `claude --effort xhigh`, then `/goal <paste>`. If you start Claude Code through
  a wrapper script or shell function, make sure it forwards its arguments to `claude`.
- **Resume:** `claude --effort xhigh --resume` (or `--continue`), so a restored goal never
  runs a turn at the default level. `/effort xhigh` inside a running session also works,
  but lasts only for that session.
- `CLAUDE_CODE_EFFORT_LEVEL` in the environment overrides both; make sure it is unset.
- Without a flag, the session uses your settings default (`effortLevel` / `modelSettings`
  in `~/.claude/settings.json`, or the model's built-in default).

Which level (judgment, not from the docs):

| Run shape | Level |
|---|---|
| Mechanical, finish line is a test or checker (migrations, bulk edits, extraction) | `high` |
| Planning, design, adversarial review, safety-critical content, unfamiliar code | `xhigh` |
| Short runs that need the hardest reasoning; no documented cost guidance, so not the default for multi-hour goals | `max` |
| `low` / `medium` | not recommended for long `/goal` work |

**Do not put `ultrathink` or "think hard/carefully" in the goal text.** Current models think
before every reply anyway, and `ultrathink` in a goal condition fires on every turn as an
invisible boost on top of the chosen level, so nobody knows the real depth of a turn.
`check-goal.sh` warns when it finds one.

## Workflow

1. **Copy the template** from this skill's directory into your working state dir:
   `cp <this-skill-dir>/templates/GOAL.template.md <STATE-DIR>/GOAL.md`
2. **Fill every `<PLACEHOLDER>`** and delete the guidance comments. The fixed scaffolding
   (resumability protocol, method, review gate, end-of-turn surfacing, turn cap) is already
   written — you only supply the goal, boundaries, deliverables, and DONE condition.
3. **Pick the reasoning effort** (section above). Copy the skill's
   `templates/PROGRESS.template.md` to `<STATE-DIR>/PROGRESS.md` and fill its phases and the
   `Reasoning effort` line before launch (the goal only creates `PROGRESS.md` if it is missing,
   so pre-creating it is how the level gets recorded).
4. **For a large effort**, also fill `PLAYBOOK.template.md` (detailed spec) and write a
   `BRIEF.md` of grounded facts, so the 4000-char condition can stay lean.
5. **Validate** — this is the primary check, run it every time:
   ```bash
   bash <this-skill-dir>/check-goal.sh <STATE-DIR>/GOAL.md
   ```
   It reports character + byte count vs 4000, flags non-ASCII, and greps for the required
   elements (progress-file-first, resume/continue, turn counter, end-of-turn surfacing,
   DONE-WHEN, subagents, evidence, boundaries). Fix every FAIL; review the WARNs.
6. **Review** (the user usually wants this): have a second model review it adversarially —
   e.g. Codex via the `calling-codex` skill (a separate plugin in this marketplace), or any
   other model you can reach — and optionally a fresh subagent. Apply the findings, then
   re-validate.
7. **Run it:** start the session with `claude --effort <level>`, then
   `/goal <paste the contents of GOAL.md>`. Pair with auto mode so each turn runs unattended.
   **To resume after any stop:** `claude --effort <level> --resume`, and send the same `/goal`
   text again if the goal is no longer active.

## What the template bakes in (so you stop retyping it)

- **Resumability contract** — read `PROGRESS.md` first; resume from the first unchecked
  item; read existing deliverables before editing; "must CONTINUE, never restart";
  idempotent increments; append evidence + tick + increment the cumulative turn counter.
- **Effort is a launch choice, not template text** — the level lives in `PROGRESS.md` and on
  the `claude --effort` command line; the template has no thinking keyword.
- **Subagent delegation** — delegate independent work, keep working while they run, cheaper
  models for grunt work, keep orchestrator context lean; a fresh verifier subagent every ~N phases.
- **No fabrication** — ground every claim in a tool result; say so when unverified.
- **Autonomy + no early stop** — proceed on reversible actions; pause only for genuinely
  user-only decisions; don't end a turn on a promise.
- **Transcript-checkable completion** — end-of-turn checklist surfacing; a cumulative turn
  counter in `PROGRESS.md` so the turn cap survives resumes; a DONE-WHEN provable from the turn.
- **Review gate** — a second model with enough access to verify the deliverables + a fresh subagent, findings resolved in `REVIEW.md`.

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
