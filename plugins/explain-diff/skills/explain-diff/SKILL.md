---
name: explain-diff
description: Turn a ticket, branch, or commit range into a visual HTML review explainer (published as a private Artifact) — background before diff, one interactive walker for the core mechanism, a literate walkthrough in execution order, a cross-repo readiness verdict, and a 5-question sign-off quiz. Use when asked to "explain this diff/ticket/branch", "make an explainer", "explain-diff TICKET-123", or to prepare a change so a human can review and truly understand it (Geoffrey Litt's "explain diff" / speed-regulator pattern).
---

# explain-diff

Produce a **review explainer** for a code change: a single self-contained HTML page
that teaches the change instead of dumping the diff. The reader is the engineer who
must sign off — the page's job is that they finish it *actually understanding* the
change (the quiz at the bottom is the speed regulator: don't pass the code along
until you can pass the quiz).

Input (args): one or more ticket keys (Jira / GitHub / Linear), a branch, or a commit
range. One explainer per ticket/change; for a series, number them ("ticket 2 of 5")
and keep one visual design across the series.

## Non-negotiable ground rules

1. **Verify before claiming.** Every "done / landed / missing / compatible" statement
   must be checked in the actual code — both sides of any cross-repo contract (the
   producer's code AND the consumer's code). Run the test suite if feasible and report
   the real numbers. If a remote ref may be stale (sandbox can't fetch), say so and
   date the snapshot ("as of the last visible fetch, Jul 11").
2. **Distinguish knowledge tiers honestly**: verified-in-code · recorded-in-notes ·
   inferred. Ticket status is routinely stale — never report it as ground truth.
3. **Collect the cross-team gaps.** Anything the counterpart team must still do that
   is *not in writing* on a ticket is a finding. Offer to draft/post the tracker
   comment (posting is gated on the user's go-ahead — outward action).
4. **Don't over-build.** One interactive element per page, chosen because it teaches
   the change's core mechanism — not decoration. Vanilla JS, ~60 lines, no libraries
   (Artifacts have a strict CSP: no external resources at all).

## Process

1. **Scope.** Resolve args → tickets (fetch from the tracker with comments if one is
   connected; if the key is an epic, list children and confirm which are in scope).
   Load any project memory/notes about them.
2. **Gather truth.** Git: the commits, net diff, file footprint (`git show --stat`,
   `git diff A B -- paths`). Tracker: goal, rescopes, comments (who was told what,
   when). Cross-repo: read the counterpart's code at its current visible ref. Tests:
   run the offline suite when cheap; classify failures (regression vs environmental)
   before reporting.
3. **Find the core mechanism** — the one design idea the reviewer must internalize
   (a fail-closed flag, an idempotency scheme, a validation grammar…). The
   interactive walker is built around *that*.
4. **Write the page** from `references/template.html` (copy it, fill the slots —
   don't design from scratch; the series look is: paper/teal/plum tokens, dark-mode
   via tokens, Charter body + Avenir headings, actor color-coding: teal = this
   repo/your side, plum = counterpart, grey = client).
   Section order is fixed (Litt structure):
   - **Header + verdict cards** (4 cards: your side / their side / blocking gate /
     posture). Lead with the outcome.
   - **01 Background** — how the system worked *before*; actor lanes if multi-service.
   - **02 Intuition** — the goal in plain language + the wire/data shape before→after
     with small concrete payloads.
   - **03 Interactive walker** — 4–6 scenario buttons; each renders the same fixed
     slots (input → route/flags → output). Pick the walker type that fits:
     *scenario-flags* (state machine decisions), *state-timeline* (before/after chips
     of a store/thread), *behavior-judge* (input → verdict → what user receives).
   - **04 Literate walkthrough** — the diff grouped by **execution order**, not file
     order; 2–4 sentences of *why* before each excerpt; real code, trimmed; one step
     for the counterpart's side. Include review history (what adversarial review
     caught) and any decision consciously held against review.
   - **05 Readiness** — numbered deploy/integration rail with per-step owner pills and
     blocked/ready/open states; then "loose ends" (stale tickets, unposted contracts,
     pending benchmarks).
   - **06 Quiz** — 5 medium multiple-choice questions targeting the load-bearing
     subtleties (not trivia); answers in `<details>` explaining why right AND why the
     tempting wrong answer is wrong.
   - **Footer** — sources with commit hashes, refs + dates, suite numbers.
5. **Publish** with the Artifact tool (private by default): one emoji favicon per
   ticket (stable across republishes), title `TICKET-123 · <short name>`, series
   numbering in the eyebrow. No Artifact tool available? Save the HTML and open it
   in a browser instead.
6. **Chat summary** (the artifact link is not enough): TL;DR verdict first, then goal /
   their side / your side (with verification evidence) / open actions, one insight
   worth keeping, and the offer to proceed to the next ticket. Keep it shorter than
   the page — the page carries the detail.
7. **Notes.** If the project keeps per-ticket memory/notes, record anything durable
   this produced (posted comments with ids, verified gaps, artifact URLs).

## Quality bar (learned from real review series)

- The walker scenarios must include the *failure* paths — that's where designs earn
  their keep (fail-closed, fallback, stale/no-op cases).
- State guarantees in tiers when they honestly differ (e.g. "language-agnostic /
  English best-effort / design-owned") — a validator's *limits* are part of the review.
- If the change fills a gap the counterpart's design left open, prove it from their
  design doc before saying "consistent with the design" — quote where the doc is
  silent. Reviewers will ask ("is this definitely not how they designed it?").
- Escape `&` `<` `>` in code excerpts; wide content scrolls in its own container;
  respect `prefers-reduced-motion`; keyboard-focus states on buttons and `<summary>`.
