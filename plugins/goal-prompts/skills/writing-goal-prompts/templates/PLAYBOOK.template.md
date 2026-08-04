# <Effort> — Playbook (the working spec)

> Use a PLAYBOOK only when the goal is too large to fully specify inside the 4000-char
> condition. The condition points here; this file carries the detail. Read order every
> turn: PROGRESS.md -> this file -> BRIEF.md (if any).

## Deliverables
1. <FILE-1> — <full spec: what sections, what it must decide/contain>.
2. <FILE-N> — <...>.
3. PROGRESS.md — the checklist/state file; initialize from the phase list below.

## Phases
**Phase 0 — Orient & resume.** Read the state file; create PROGRESS.md if missing;
spot-verify the load-bearing baseline facts against the source (don't trust a dated brief blindly).

**Phase 1 — <name>.** <what to do; which subagents to delegate; what the deliverable is>.

**Phase N — Finalize.** Cross-link, ensure consistency, mark every phase complete, surface the checklist.

## Working method
- Ground every progress claim in a tool result from this session; report only what you can point to.
- Delegate independent investigation to subagents and keep working while they run; cheaper models for grunt work.
- Every ~<N> phases, spawn a fresh-context verifier subagent to check deliverables against this playbook.
- Recommend, don't survey; decide and justify. Depth goes in the deliverables, not user-facing chatter.
- Autonomy: proceed on reversible actions; pause only for genuinely user-only decisions (record them in PROGRESS.md).
- End each turn by printing the PROGRESS.md checklist + cumulative turn count (the /goal evaluator only sees the transcript).

## PROGRESS.md template
Copy `PROGRESS.template.md` (next to this template in the skill's `templates/`
directory) into the state dir alongside this playbook, or let the goal create
PROGRESS.md from the phase list above on its first turn.
