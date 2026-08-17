#!/usr/bin/env bash
# check-loop.sh — heuristic validator for a filled loop pack.
# Usage: check-loop.sh [--runtime loop|goal|workflow|schedule] CONTRACT LEDGER [PROMPT]
#   runtime loop (default): all three files required; prompt checks run against
#     the first fenced block only (the text actually pasted after /loop).
#   runtime goal|workflow|schedule: contract + ledger only (the /goal prompt is
#     validated by writing-goal-prompts/check-goal.sh; Workflow/schedule carry
#     no tick prompt).
# Exit 0 = ok (warnings allowed), 1 = blocking FAILs, 2 = usage/input error.
# Heuristic: presence checks (extended regexes), not meaning — it cannot tell
# "never push" from "pushing is allowed". PASS means "the scaffolding is there";
# the adversarial review gate is the semantic check.

set -u

RUNTIME=loop
if [ "${1:-}" = "--runtime" ]; then
  RUNTIME="${2:-}"; shift 2 || { echo "usage: --runtime loop|goal|workflow|schedule" >&2; exit 2; }
  case "$RUNTIME" in loop|goal|workflow|schedule) ;; *) echo "unknown runtime: $RUNTIME" >&2; exit 2;; esac
fi

if [ "$RUNTIME" = loop ]; then
  [ $# -eq 3 ] || { echo "usage: $0 [--runtime loop] CONTRACT LEDGER PROMPT (all three required for /loop)" >&2; exit 2; }
else
  [ $# -eq 2 ] || { echo "usage: $0 --runtime $RUNTIME CONTRACT LEDGER" >&2; exit 2; }
fi

CONTRACT="$1"; LEDGER="$2"; PROMPT="${3:-}"
for f in "$CONTRACT" "$LEDGER" ${PROMPT:+"$PROMPT"}; do
  [ -r "$f" ] || { echo "cannot read: $f" >&2; exit 2; }
done
# arg-shape sanity: a ledger arg that looks like a tick prompt is mis-bound
if grep -q 'RECONCILE' "$LEDGER" && ! grep -q '^## Lock' "$LEDGER"; then
  echo "args look swapped: '$LEDGER' contains RECONCILE but no '## Lock' stanza" >&2; exit 2
fi

fails=0; warns=0
fail() { echo "FAIL [$1] $2"; fails=$((fails+1)); }
warn() { echo "WARN [$1] $2"; warns=$((warns+1)); }
ok()   { echo " ok  [$1] $2"; }

# req FILE LABEL EXT-REGEX DESCRIPTION  (add -i via req_i for case-insensitive)
req()   { if grep -qE  "$3" "$1"; then ok "$2" "$4"; else fail "$2" "$4 (pattern: $3)"; fi; }
req_i() { if grep -qiE "$3" "$1"; then ok "$2" "$4"; else fail "$2" "$4 (pattern: $3)"; fi; }
# breq: same but against a string (the extracted paste block)
breq()  { if printf '%s\n' "$5" | grep -qE "$3"; then ok "$2" "$4"; else fail "$2" "$4 (pattern: $3, scoped to the fenced block)"; fi; }

# --- unfilled-template detection (all provided files) --------------------------
# Placeholder grammar (must match the templates): <UPPERCASE DIGITS SPACE _ ->.
# Literal "<item>" (ledger/tick wording) is the sole sanctioned lowercase token.
for f in "$CONTRACT" "$LEDGER" ${PROMPT:+"$PROMPT"}; do
  base=$(basename "$f")
  if grep -qE '<[A-Z][A-Z0-9 _-]*>' "$f"; then
    fail "$base" "unfilled <PLACEHOLDER> remains: $(grep -oE '<[A-Z][A-Z0-9 _-]*>' "$f" | sort -u | head -6 | tr '\n' ' ')"
  else
    ok "$base" "no unfilled placeholders"
  fi
  stray=$(grep -oE '<[A-Za-z][^>]*>' "$f" | grep -v '^<item>$' | grep -vE '^<[A-Z][A-Z0-9 _-]*>$' | sort -u | head -6 | tr '\n' ' ')
  [ -n "$stray" ] && warn "$base" "suspicious <...> tokens (unfilled free-form placeholder?): $stray"
  grep -q '<!--' "$f" && fail "$base" "guidance comments (<!-- -->) not deleted"
done

# --- contract -------------------------------------------------------------------
C=$(basename "$CONTRACT")
req   "$CONTRACT" "$C" '^## 1\. Outcome'            "outcome section present"
req_i "$CONTRACT" "$C" 'evidence'                   "evidence named"
req_i "$CONTRACT" "$C" 'checked by'                 "an independent checker is named"
req   "$CONTRACT" "$C" '^## 2\. Scope'              "scope + non-goals section"
req_i "$CONTRACT" "$C" 'non-goals'                  "non-goals listed"
if grep -qiE 'Isolation.*(serialized|authorized by)' "$CONTRACT"; then
  ok "$C" "isolation mode: serialized OR worktrees-authorized-by a recorded decision"
else
  fail "$C" "mandatory Isolation line missing or invalid (must say 'serialized (no worktrees)' or 'worktrees authorized by <decision id>')"
fi
req   "$CONTRACT" "$C" '^## 3\. Invariants'         "invariants section"
req_i "$CONTRACT" "$C" 'measuring instrument'       "measuring-instrument immutability clause"
req   "$CONTRACT" "$C" '^## 4\. Budgets'            "budgets section"
req_i "$CONTRACT" "$C" 'no-progress'                "no-progress rule"
req_i "$CONTRACT" "$C" 'retries'                    "retry ceiling"
req_i "$CONTRACT" "$C" 'concurrent'                 "concurrency ceiling"
req   "$CONTRACT" "$C" '^## 5\. Decision rights'    "decision-rights section"
req_i "$CONTRACT" "$C" 'agent-autonomous'           "autonomous class present"
req_i "$CONTRACT" "$C" 'proposes, human ratifies|proposes-human-ratifies' "propose/ratify class present"
req   "$CONTRACT" "$C" 'Delegable'                  "delegable outward-actions class (default queue; scoped grant)"
req_i "$CONTRACT" "$C" 'session capabilities'       "session capabilities declared (or 'none')"
req   "$CONTRACT" "$C" 'git push'                   "standing human-only: push"
req   "$CONTRACT" "$C" 'Jira'                       "Jira handling present (queued by default / scoped grant)"
req_i "$CONTRACT" "$C" 'production data|PHI'        "standing human-only: production data"
req_i "$CONTRACT" "$C" 'secrets|\.env'              "standing human-only: secrets / .env"
req   "$CONTRACT" "$C" '^## 6\. Stop policy'        "stop-policy section"
req   "$CONTRACT" "$C" 'PROGRESS'                   "tick outcome: PROGRESS"
req   "$CONTRACT" "$C" 'WAITING'                    "tick outcome: WAITING"
for s in SUCCESS HUMAN-GATE BLOCKED BUDGET NO-PROGRESS; do
  req "$CONTRACT" "$C" "$s" "terminal stop reason: $s"
done
req_i "$CONTRACT" "$C" 'decision packet'            "escalation = decision packet"
req_i "$CONTRACT" "$C" 'literal reply'              "packets end with the literal reply to send (plain-words rule)"
req   "$CONTRACT" "$C" '^## 7\. Gates'              "gates section"
req   "$CONTRACT" "$C" 'blocks-dispatch|blocks-merge|allows-provisional-land|blocks-close' "gate Effect (typed enum) present"
req_i "$CONTRACT" "$C" 'at land time'               "gates re-checked at land time"
req   "$CONTRACT" "$C" '^## 8\. Before the first tick' "launch checklist section"
req_i "$CONTRACT" "$C" 'uncommitted'                "uncommitted-work launch check"
req   "$CONTRACT" "$C" '^## 9\. Item contract'      "item-contract (worker briefing) section"
req   "$CONTRACT" "$C" 'CLAUDE\.md'                 "workers ordered to read root + repo CLAUDE.md"
req_i "$CONTRACT" "$C" 'self-merge'                 "worker prohibition: self-merge"
req_i "$CONTRACT" "$C" 'infra|terraform'            "worker prohibition: infra apply"

# --- ledger ---------------------------------------------------------------------
L=$(basename "$LEDGER")
req   "$LEDGER" "$L" '^## Lock'                     "lock stanza"
req_i "$LEDGER" "$L" 'unclaimed'                    "ships unclaimed; first tick claims"
req_i "$LEDGER" "$L" 'lease window'                 "wall-clock lease (never tick-denominated)"
req_i "$LEDGER" "$L" 'heartbeat'                    "heartbeat recorded"
req_i "$LEDGER" "$L" 'co-dispatch'                  "second-dispatcher exit rule"
req   "$LEDGER" "$L" '^## Budget'                   "durable budget stanza"
req_i "$LEDGER" "$L" 'no-progress streak'           "no-progress accounting"
req_i "$LEDGER" "$L" 'ticks used'                   "tick counter"
req   "$LEDGER" "$L" '^## States'                   "state machine section"
req_i "$LEDGER" "$L" 'reserve-first'                "reserve-before-spawn rule"
req_i "$LEDGER" "$L" 'quarantin'                    "dirty orphans quarantined, never deleted"
req   "$LEDGER" "$L" 'done-reported'                "done-reported state defined"
req   "$LEDGER" "$L" 'Base SHA'                     "base SHA per item"
req_i "$LEDGER" "$L" 'never both'                   "resume-or-redispatch, never both"
req   "$LEDGER" "$L" '^## Decision queue'           "decision queue section"
req_i "$LEDGER" "$L" 'the dispatcher (records|transcribes)' "human answers in chat; dispatcher records (single writer)"
req   "$LEDGER" "$L" '^## Event log'                "append-only event log"
req_i "$LEDGER" "$L" 'per tick'                     "one event-log line per tick (no-op ticks included)"
req_i "$LEDGER" "$L" 'only the dispatcher'          "single-writer rule"
req_i "$LEDGER" "$L" 'never close|Partial items never' "partial-item ticket protection"

# --- tick prompt (loop runtime only; checks scoped to the pasted block) ---------
if [ -n "$PROMPT" ]; then
  P=$(basename "$PROMPT")
  block=$(awk '/^```/{n++; next} n==1' "$PROMPT")
  if [ -z "$block" ]; then
    fail "$P" "no fenced block found — nothing to paste after /loop"
  else
    nblocks=$(grep -c '^```' "$PROMPT")
    [ "$nblocks" -gt 2 ] && warn "$P" "multiple fenced blocks; only the FIRST is validated/pasted"
    printf '%s\n' "$block" | head -1 | grep -q '^/loop' \
      && ok "$P" "block starts with /loop" \
      || fail "$P" "first fenced block does not start with /loop"
    breq "$PROMPT" "$P" 'RECONCILE'                "tick step: reconcile"                       "$block"
    breq "$PROMPT" "$P" 'CHECK completions'        "tick step: check completions"               "$block"
    breq "$PROMPT" "$P" 'RECOMPUTE'                "tick step: recompute eligibility"           "$block"
    breq "$PROMPT" "$P" 'DISPATCH'                 "tick step: dispatch"                        "$block"
    breq "$PROMPT" "$P" 'dispatching'              "reserve-first wording"                      "$block"
    breq "$PROMPT" "$P" 'STOP'                     "tick ends in STOP"                          "$block"
    breq "$PROMPT" "$P" 'do no implementation'     "dispatcher does not implement"              "$block"
    breq "$PROMPT" "$P" 'prohibitions verbatim'    "workers get the standing prohibitions"      "$block"
    breq "$PROMPT" "$P" 'CLAUDE\.md'               "workers ordered to read CLAUDE.md"          "$block"
    breq "$PROMPT" "$P" 'FORECAST|forecast'        "batch tables demoted to forecast"           "$block"
    breq "$PROMPT" "$P" 'at land time'             "gates re-checked at land time"              "$block"
    breq "$PROMPT" "$P" 'immediately before merg'  "pre-merge re-check (gates + target SHA)"    "$block"
    breq "$PROMPT" "$P" 'adversarial review'       "merge-time adversarial review named"        "$block"
    breq "$PROMPT" "$P" 'QUARANTINED|quarantin'    "dirty orphans quarantined"                  "$block"
    breq "$PROMPT" "$P" 'lease'                    "lock claimed per lease rules"               "$block"
    breq "$PROMPT" "$P" 'Budget stanza'            "budget stanza updated each tick"            "$block"
    breq "$PROMPT" "$P" 'PROGRESS'                 "tick outcome PROGRESS"                      "$block"
    breq "$PROMPT" "$P" 'WAITING'                  "tick outcome WAITING"                       "$block"
    breq "$PROMPT" "$P" 'never execute outward'    "outward actions queued, never executed"     "$block"
    breq "$PROMPT" "$P" 'remove the worktree'      "authorized worktrees removed after landing" "$block"
    breq "$PROMPT" "$P" '10 lines'                 "<=10-line tick report"                      "$block"
    chars=$(printf %s "$block" | wc -m | tr -d ' ')
    bytes=$(printf %s "$block" | wc -c | tr -d ' ')
    nonascii=$(printf %s "$block" | tr -d '[:space:]' | LC_ALL=C grep -o '[^ -~]' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$chars" -gt 4000 ] || [ "$bytes" -gt 4000 ]; then
      warn "$P" "block is $chars chars / $bytes bytes (>4000 — fine for /loop, hard limit for /goal; trim by citing contract sections)"
    else
      ok "$P" "block $chars chars / $bytes bytes (<=4000)"
    fi
    [ "$nonascii" -gt 0 ] && ok "$P" "note: $nonascii non-ASCII chars in block (multibyte — relevant only near the 4000-byte edge)"
  fi
fi

echo
echo "== $fails FAIL, $warns WARN (runtime: $RUNTIME) =="
[ "$fails" -eq 0 ] || exit 1
exit 0
