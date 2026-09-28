#!/usr/bin/env bash
# check-goal.sh — validate a /goal prompt file against the /goal constraints.
#
# /goal (Claude Code) rules this checks for:
#   - the argument is BOTH the directive AND a completion condition;
#   - a small/fast model (Haiku) evaluates the condition each turn but can
#     ONLY read the transcript — it cannot run tools or read files;
#   - on --resume the turn counter/timer reset and context may be fresh, so
#     durable state MUST live in files on disk;
#   - the condition has a hard 4000-CHARACTER limit.
#
# Usage: bash check-goal.sh path/to/GOAL.md
set -u

file="${1:-}"
if [ -z "$file" ] || [ ! -f "$file" ]; then
  echo "usage: bash check-goal.sh <goal-file>" >&2
  exit 2
fi

# The pasted /goal argument carries no trailing newline; command substitution strips
# trailing newlines for the count either way (the perl call just normalizes CRLF etc).
content="$(perl -0pe 's/\n\z//' "$file" 2>/dev/null || cat "$file")"
# Count Unicode characters (not bytes) even on a non-UTF-8 locale; fall back to `wc -m`.
chars=$(printf '%s' "$content" | perl -MEncode=decode -0777 -ne 'print length(decode("UTF-8", $_))' 2>/dev/null \
        || printf '%s' "$content" | wc -m | tr -d ' ')
bytes=$(printf '%s' "$content" | wc -c | tr -d ' ')
nonascii=$(printf '%s' "$content" | LC_ALL=C grep -c '[^ -~]' 2>/dev/null || true)

fail=0; warn=0
pass()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
warned() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; warn=$((warn+1)); }
failed() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }
has()    { printf '%s' "$content" | grep -iqE "$1"; }
chk()    { if has "$2"; then pass "$1"; else failed "$1 (pattern: /$2/i)"; fi; }
chkw()   { if has "$2"; then pass "$1"; else warned "$1 (pattern: /$2/i)"; fi; }
absent() { if has "$2"; then failed "$1 (found pattern that should be absent: /$2/)"; else pass "$1"; fi; }
absentw(){ if has "$2"; then warned "$1 (found: /$2/i)"; else pass "$1"; fi; }

echo "Checking: $file"
echo
echo "Size (limit is 4000 characters):"
if [ "$chars" -le 4000 ]; then pass "characters: $chars / 4000"
else failed "characters: $chars / 4000 — OVER the /goal limit"; fi
if [ "$bytes" -le 4000 ]; then pass "bytes: $bytes / 4000"
else warned "bytes: $bytes > 4000 — a byte-counted limit would reject; trim or use ASCII"; fi
if [ "${nonascii:-0}" -eq 0 ]; then pass "ASCII-only (chars == bytes, byte-safe)"
else warned "$nonascii line(s) contain bytes outside printable ASCII (em-dash —, arrow →, × cost 3 bytes each)"; fi

echo
echo "Required elements (heuristic — grep can't judge quality, only presence):"
absent "no unfilled placeholders or template comments"  '<[A-Za-z][^>]*>|<!--|-->'
chk  "reads a progress/state file FIRST each turn"      'FIRST:.*PROGRESS|read .*PROGRESS.*first|PROGRESS\.md.*first'
chk  "resumability: continue, never restart"            'resume|continue|never restart'
chkw "idempotent increments"                            'idempoten'
chk  "cumulative turn counter / turn cap"               'turn count|turn counter|stop .*turns'
chk  "end-of-turn surfacing (evaluator sees transcript only)" 'each turn|end each turn|surface|print'
chk  "explicit, transcript-verifiable DONE-WHEN"        'done when|complete when|condition is met'
chkw "delegates independent work to subagents"          'subagent'
chkw "grounds progress claims in evidence"              'evidence|tool result|verify'
chkw "states boundaries (what NOT to do)"               'do not|do NOT|only:|read-only|planning only'
absentw "no thinking keyword (set effort at launch: claude --effort)" 'ultrathink|think (hard|harder|carefully|deeply)'

echo
if [ "$fail" -gt 0 ]; then
  printf '\033[31mFAILED\033[0m: %d blocker(s), %d warning(s). Fix blockers before running /goal.\n' "$fail" "$warn"
  exit 1
elif [ "$warn" -gt 0 ]; then
  printf '\033[33mPASS with %d warning(s)\033[0m — review the warnings, then run /goal.\n' "$warn"
  exit 0
else
  printf '\033[32mALL CHECKS PASSED\033[0m — ready to run /goal.\n'
  exit 0
fi
