<!--
  Fill every <PLACEHOLDER>, delete these comments, keep it ASCII-only and <=4000 chars,
  then validate:  bash <writing-goal-prompts skill dir>/check-goal.sh <this-file>
  Paste the result after `/goal`. To resume later, send the exact same text again.
  Drop the PLAYBOOK/BRIEF sentence if the whole spec fits in this file.
-->
<ONE-SENTENCE GOAL: what to produce or achieve, e.g. "Produce a reviewed migration plan ... as documents under docs/<effort>/">. <BOUNDARIES: what NOT to do, e.g. "Planning only: write docs, do NOT implement code, deploy, or run destructive commands.">

EVERY TURN, FIRST: read <STATE-DIR>/PROGRESS.md<, then PLAYBOOK.md, then BRIEF.md>. If PROGRESS.md is missing, create it from the phase list<in PLAYBOOK.md>. Resume from the first unchecked item; read existing deliverables before editing and update them in place. Re-sending this goal must CONTINUE, never restart. Work idempotently; after each increment append a one-line evidence pointer to PROGRESS.md and tick what's done; at the end of every turn increment the cumulative turn counter exactly once.<PLAYBOOK.md is authoritative for detail; treat BRIEF.md as a dated baseline and spot-verify load-bearing facts against the source before relying on them.>

DELIVERABLES (all under <STATE-DIR>/, non-stub):
- <FILE-1>: <what it must contain>.
- <FILE-2>: <what it must contain>.
- <FILE-N>: <...>.
- PROGRESS.md: the checklist/state file (<phase list>) with the cumulative turn counter.
<- REVIEW.md: each review finding, its resolution, and the unresolved-blocker count (drop this line if there's no REVIEW GATE below).>

METHOD: ultrathink. Delegate independent investigation to subagents and keep working while they run (use cheaper models for grunt work like search/link-following/extraction); keep orchestrator context lean so resumes are cheap. Every ~<N> phases, spawn a fresh verifier subagent to check the deliverables against the spec. Ground every progress claim in a tool result; if a fact isn't verified, say so; never report a file or fact as confirmed without evidence. You run unattended across turns: for reversible actions that follow from the spec, proceed without asking; pause only for a genuinely user-only decision and record it in PROGRESS.md. Don't end a turn on a promise; do the work now.

REVIEW GATE: <DELIVERABLE(S) TO REVIEW> must be reviewed by BOTH (a) a second model (e.g. Codex via the calling-codex skill, if available) with enough read access to verify the deliverables against the source, adversarial on correctness, feasibility, and gaps; and (b) a fresh subagent that verifies claims against the source and flags anything unfounded. Resolve every finding and record it in REVIEW.md; if a review forces material change, re-review that part.

END EACH TURN by printing the PROGRESS.md checklist (item-by-item done/not-done) and the cumulative turn count. When complete, ALSO print one line of evidence per deliverable (path + section headings, so non-stub is demonstrable)<and REVIEW.md's unresolved-finding count>.

DONE WHEN, all surfaced in this turn: <the transcript-verifiable end state, e.g. "the deliverables exist and are non-stub; PROGRESS.md shows every item complete; REVIEW.md records the reviews with zero unresolved blockers">. OTHERWISE stop when PROGRESS.md's cumulative turn counter reaches <TURN-CAP>, reporting which items remain and why.
