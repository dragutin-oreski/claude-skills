#!/usr/bin/env bash
# Smoke test: is Codex installed and logged in, can its own sandbox start here, and does a
# real review job run end to end through codex-job? Costs one short Codex call.
#
# Usage: bash smoke.sh      (from anywhere)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
JOB="$HERE/scripts/codex-job"
CODEX="${CODEX_BIN:-codex}"

command -v "$CODEX" >/dev/null 2>&1 || { echo "codex not found (npm install -g @openai/codex)"; exit 1; }
echo "codex: $(command -v "$CODEX") ($("$CODEX" --version 2>&1 | tail -1))"
echo "auth: $("$CODEX" login status 2>&1 | tail -1)"
if "$CODEX" sandbox -- /bin/sh -c true >/dev/null 2>&1; then
  echo "codex sandbox: works (jobs run in Codex's own sandbox)"
else
  echo "codex sandbox: cannot start here (nested sandbox) — jobs need full access, allowed by a human"
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/codex-smoke.XXXX")"
git -C "$work" init -q && printf 'def add(a, b):\n    return a - b\n' > "$work/calc.py"
echo "Read calc.py. Is add() correct? Answer in one sentence and cite the line." > "$work/brief.md"
out="$(bash "$JOB" start --prompt "$work/brief.md" --cd "$work" --name smoke --timeout 300)"
echo "$out" | head -2
job="$(echo "$out" | sed -n 's/^job: //p')"
[ -n "$job" ] && echo "$out" | grep -qE '^state: (running|done)' || { echo "$out"; echo "smoke-failed"; exit 1; }
out="$(bash "$JOB" wait "$job" --max 300)"
echo "$out" | grep -E '^(state|commands|warning):'
if echo "$out" | grep -q '^state: done' && ! echo "$out" | grep -q '^warning'; then
  bash "$JOB" result "$job" | tail -5; echo; rm -rf "$work"; echo "smoke-ok"
else
  echo "$out"; echo "smoke-failed"; exit 1
fi
