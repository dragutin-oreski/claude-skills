#!/usr/bin/env bash
# Offline tests for codex-job, against tests/fake-codex. No network, no real Codex.
#   bash tests/test-codex-job.sh            # with the bash on PATH
#   /bin/bash tests/test-codex-job.sh       # macOS: also proves bash 3.2 works
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
JOB_SCRIPT="$HERE/../skills/calling-codex/scripts/codex-job"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/codex-job-test.XXXX")"
WORK="$(cd "$WORK" && pwd -P)"
export CODEX_BIN="$HERE/fake-codex" CODEX_JOBS_DIR="$WORK/jobs" FAKE_CODEX_LOG="$WORK/fake.log"
export XDG_CONFIG_HOME="$WORK/config" FAKE_CODEX_PIDFILE="$WORK/fake.pid"   # never the real allow file
BASH_BIN="${BASH:-bash}"
pass=0 fail=0 out=""

cj() { "$BASH_BIN" "$JOB_SCRIPT" "$@"; }
field() { sed -n "s/^$1: //p" | head -1; }
check() {  # name command... — on failure, shows the last codex-job output
  local name="$1"; shift
  if "$@"; then pass=$((pass + 1)); echo "ok   $name"
  else fail=$((fail + 1)); echo "FAIL $name"; printf '%s\n' "$out" | sed 's/^/       /' | head -12; fi
}
has() { printf '%s\n' "$out" | grep -qE "$1"; }
lacks() { ! has "$1"; }
fake_gone() { local p; p="$(cat "$FAKE_CODEX_PIDFILE" 2>/dev/null)"; [ -n "$p" ] && ! kill -0 "$p" 2>/dev/null; }
reset_env() {
  unset FAKE_CODEX_MODE FAKE_CODEX_SLEEP FAKE_SANDBOX_OK FAKE_SANDBOX_SLEEP FAKE_SANDBOX_ERR CODEX_JOB_ALLOW_FULL
  rm -rf "$XDG_CONFIG_HOME" "$FAKE_CODEX_PIDFILE"; : > "$FAKE_CODEX_LOG"
}
allow_full() { mkdir -p "$XDG_CONFIG_HOME/codex-job" && touch "$XDG_CONFIG_HOME/codex-job/allow-full"; }
run_job() { out="$(cj start "$@")"; job="$(printf '%s\n' "$out" | field job)"; out="$(cj wait "$job" --max 20)"; }

echo "please review" > "$WORK/brief.md"
repo="$WORK/repo"; mkdir -p "$repo"
git -C "$repo" init -q && echo a > "$repo/a.txt" && git -C "$repo" add a.txt \
  && git -C "$repo" -c user.email=t@t -c user.name=t commit -qm init

# --- sandbox policy
reset_env
out="$(cj start --prompt "$WORK/brief.md" --cd "$repo")"; rc=$?
check "nested sandbox without permission: refused" [ "$rc" = 1 ]
check "refusal tells the human how to allow it" has 'allow-full'
check "no codex run after refusal" bash -c "! grep -q '^exec' '$FAKE_CODEX_LOG'"

reset_env; export CODEX_JOB_ALLOW_FULL=1
out="$(cj start --prompt "$WORK/brief.md" --cd "$repo" --sandbox read-only)"; rc=$?
check "explicit read-only in a nested sandbox: refused, not blind" [ "$rc" = 1 ]

reset_env; export FAKE_SANDBOX_OK=1
run_job --prompt "$WORK/brief.md" --cd "$repo"
check "working inner sandbox: review runs read-only" grep -q 'sandbox_mode="read-only"' "$FAKE_CODEX_LOG"
check "working inner sandbox: no full access even if allowed" bash -c "! grep -q danger-full-access '$FAKE_CODEX_LOG'"

reset_env; allow_full
run_job --prompt "$WORK/brief.md" --cd "$repo" --name basic
check "allow file enables full access" grep -q 'sandbox_mode="danger-full-access"' "$FAKE_CODEX_LOG"
check "approval policy is never" grep -q 'approval_policy="never"' "$FAKE_CODEX_LOG"

# --- the normal flow
reset_env; allow_full
out="$(cj start --prompt "$WORK/brief.md" --cd "$repo" --name basic)"; job="$(printf '%s\n' "$out" | field job)"
check "start reports started, running or done" has '^state: (started|running|done)$'
out="$(cj wait "$job" --max 20)"; rc=$?
check "wait reports done" has '^state: done$'
check "wait exits 0 when done" [ "$rc" = 0 ]
check "done reports successful commands" has '^commands: 1 of 1 succeeded'
check "clean review: no warnings" lacks '^warning'
check "result prints the final message" grep -q 'fake reply' <<<"$(cj result "$job")"
check "prompt has the read-only preamble" grep -q 'Read-only' "$job/prompt.md"
check "prompt has the output format" grep -q 'APPROVE-WITH-FIXES' "$job/prompt.md"
check "prompt has the brief" grep -q 'please review' "$job/prompt.md"
check "prompt has the working dir filled in" grep -q "directory is $repo" "$job/prompt.md"
check "no model flag by default" bash -c "! grep -q -- ' -m ' '$FAKE_CODEX_LOG'"

reset_env; allow_full
run_job --prompt "$WORK/brief.md" --cd "$repo" --mode adversarial
check "adversarial mode has its own preamble" grep -q 'should NOT ship' "$job/prompt.md"

# --- start must not hold the caller's output pipe open while Codex runs
reset_env; allow_full; export FAKE_CODEX_MODE=slow FAKE_CODEX_SLEEP=40
t0=$(date +%s); out="$(cj start --prompt "$WORK/brief.md" --cd "$repo" | cat)"; t1=$(date +%s)
job="$(printf '%s\n' "$out" | field job)"
check "start | cat returns while Codex keeps running" [ $((t1 - t0)) -lt 15 ]
check "job is running" has '^state: running$'
out="$(cj resume "$job" --prompt "$WORK/brief.md")"; rc=$?
check "resume refused while the thread is busy" [ "$rc" = 1 ]
out="$(cj wait "$job" --max 2)"
check "wait --max returns running" has '^state: running$'
out="$(cj cancel "$job")"; rc=$?
check "cancel reports cancelled" has '^state: cancelled$'
check "cancel exits 1" [ "$rc" = 1 ]
sleep 1; check "no codex process left after cancel" fake_gone

reset_env; allow_full; export FAKE_CODEX_MODE=slow FAKE_CODEX_SLEEP=60
run_job --prompt "$WORK/brief.md" --cd "$repo" --timeout 3
check "timeout stops the job" has '^state: timed-out$'
sleep 1; check "no codex process left after timeout" fake_gone

# --- failures are never reported as done
reset_env; allow_full; export FAKE_CODEX_MODE=die-early
out="$(cj start --prompt "$WORK/brief.md" --cd "$repo")"; rc=$?
check "early death: failed" has '^state: failed$'
check "early death: exits 1" [ "$rc" = 1 ]
check "early death: shows Codex's error" has 'not logged in'

reset_env; allow_full; export FAKE_CODEX_MODE=fail-after-start
run_job --prompt "$WORK/brief.md" --cd "$repo"
check "error after start: failed" has '^state: failed$'
check "error after start: shows stderr" has 'stream disconnected'

reset_env; allow_full; export FAKE_CODEX_MODE=no-output
run_job --prompt "$WORK/brief.md" --cd "$repo"
check "exit 0 without a final message: failed" has '^state: failed$'

reset_env; allow_full; export FAKE_CODEX_MODE=no-turn
run_job --prompt "$WORK/brief.md" --cd "$repo"
check "message but turn never completed: failed" has '^state: failed$'
check "says the turn did not finish" has 'did not finish its turn'

reset_env; allow_full; export FAKE_CODEX_MODE=blind
run_job --prompt "$WORK/brief.md" --cd "$repo"
check "blind review: flagged as unverified" has 'failed with sandbox errors'
check "blind review: no successful commands warning" has 'every command Codex ran failed'

# --- jobs that change files they must not
reset_env; allow_full; export FAKE_CODEX_MODE=write-file
run_job --prompt "$WORK/brief.md" --cd "$repo"
check "review that wrote files: flagged" has "tree changed: $repo"
rm -f "$repo/written-by-review.txt"

reset_env; allow_full; echo b >> "$repo/a.txt"
out="$(cj start --prompt "$WORK/brief.md" --cd "$repo" --mode review | cat)"; job="$(printf '%s\n' "$out" | field job)"
git -C "$repo" add a.txt            # staging only: working file and HEAD unchanged
out="$(cj wait "$job" --max 20)"
check "staging-only change is flagged" has "tree changed: $repo"
git -C "$repo" reset -q && git -C "$repo" checkout -q -- a.txt

# --- resume continues the same thread
reset_env; allow_full
run_job --prompt "$WORK/brief.md" --cd "$repo" --name first
echo "follow-up question" > "$WORK/follow.md"
run_job_resume() { out="$(cj resume "$1" --prompt "$WORK/follow.md")"; job="$(printf '%s\n' "$out" | field job)"; out="$(cj wait "$job" --max 20)"; }
run_job_resume "$job"
check "resume finishes" has '^state: done$'
check "resume passes the thread id" grep -q 'exec resume 11111111-2222-3333-4444-555555555555' "$FAKE_CODEX_LOG"
check "resume sets the sandbox explicitly" bash -c "grep 'exec resume' '$FAKE_CODEX_LOG' | grep -q 'sandbox_mode='"
check "resume sends only a short reminder" bash -c "! grep -q 'Output format' '$job/prompt.md' && grep -q 'follow-up question' '$job/prompt.md'"
check "resumed reply came from a resume" grep -q 'resume=1' "$job/result.md"
e1="$(cj status "$job" | field elapsed)"; sleep 2; e2="$(cj status "$job" | field elapsed)"
check "elapsed stops at the final state" [ "$e1" = "$e2" ]

# --- task mode
reset_env; allow_full
out="$(cj start --prompt "$WORK/brief.md" --cd "$repo" --mode task)"; rc=$?
check "task refuses the main checkout" [ "$rc" = 1 ]
check "task refusal explains worktrees" has 'worktree add'
git -C "$repo" worktree add -q "$WORK/wt" -b task-branch
run_job --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task
check "task runs in a worktree" has '^state: done$'
check "task preamble" grep -q 'Change files only inside' "$job/prompt.md"
check "task watches the main checkout" grep -qx "$repo" "$job/tree.1.dir"
check "task lists changed files" has '^changed_files:'
echo dirty > "$WORK/wt/dirty.txt"
out="$(cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task)"; rc=$?
check "task refuses a dirty worktree" [ "$rc" = 1 ]
rm -f "$WORK/wt/dirty.txt"
export FAKE_CODEX_MODE=slow FAKE_CODEX_SLEEP=40
out="$(cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task)"; busy="$(printf '%s\n' "$out" | field job)"
out="$(cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task)"; rc=$?
check "second task in the same worktree refused" [ "$rc" = 1 ]
cj cancel "$busy" > /dev/null; unset FAKE_CODEX_MODE FAKE_CODEX_SLEEP
check "task records its base commit" grep -q '^base_commit: [0-9a-f]' "$busy/meta"
lnk="$WORK/link"; ln -s "$repo" "$lnk"
out="$(cj start --prompt "$WORK/brief.md" --cd "$lnk" --mode task)"; rc=$?
check "task guard not fooled by a symlinked path" [ "$rc" = 1 ]

reset_env; export FAKE_SANDBOX_OK=1
run_job --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task
check "task with working inner sandbox uses workspace-write" grep -q 'sandbox_mode="workspace-write"' "$FAKE_CODEX_LOG"

# --- model / effort only when asked
reset_env; allow_full
run_job --prompt "$WORK/brief.md" --cd "$repo" --model m1 --effort high
check "model passed when asked" grep -q -- '-m m1' "$FAKE_CODEX_LOG"
check "effort passed when asked" grep -q 'model_reasoning_effort="high"' "$FAKE_CODEX_LOG"

# --- status and usage errors
check "status lists jobs" [ "$(cj status | grep -c '^state:')" -ge 5 ]
gone="$WORK/gone"; mkdir -p "$gone"; run_job --prompt "$WORK/brief.md" --cd "$gone"; rm -rf "$gone"
errs="$(cj status 2>&1 >/dev/null)"
check "status list with a vanished dir: no errors" [ -z "$errs" ]
out="$(cj status "$job")"
check "full status notes the missing dir" has 'watched directory is gone' 
check "status by job name works" bash -c "'$BASH_BIN' '$JOB_SCRIPT' status '$(basename "$job")' | grep -q '^state: done$'"
cj start --cd "$repo" > /dev/null 2>&1; check "missing --prompt fails" [ $? = 1 ]
cj start --prompt "$WORK/brief.md" --mode nope > /dev/null 2>&1; check "bad --mode is a usage error" [ $? = 2 ]
cj start --prompt "$WORK/brief.md" --sandbox full > /dev/null 2>&1; check "--sandbox full is not an option" [ $? = 2 ]
cj start --prompt "$WORK/brief.md" --timeout 0 > /dev/null 2>&1; check "zero timeout is a usage error" [ $? = 2 ]
cj bogus > /dev/null 2>&1; check "unknown command is a usage error" [ $? = 2 ]

# --- a cancel that loses the race to a finished job does not overwrite done
reset_env; allow_full
run_job --prompt "$WORK/brief.md" --cd "$repo"
out="$(cj cancel "$job")"
check "cancel after done keeps done" has '^state: done$'


# --- round-2 review regressions
reset_env; allow_full
cj start --prompt "$WORK/brief.md" --cd "$repo" --model "$(printf 'm\n--dangerously-bypass-approvals-and-sandbox')" > /dev/null 2>&1; rc=$?
check "newline in --model rejected" [ "$rc" = 2 ]
check "no codex run with an injected flag" bash -c "! grep -q dangerously '$FAKE_CODEX_LOG'"
nl="$WORK/$(printf 'brief\nstarted_at: x')"; cp "$WORK/brief.md" "$nl"
cj start --prompt "$nl" --cd "$repo" > /dev/null 2>&1; rc=$?
check "newline in --prompt path rejected" [ "$rc" = 2 ]
( cj start --prompt > /dev/null 2>&1 ); rc=$?
check "option without a value is a usage error, not a hang" [ "$rc" = 2 ]

mkdir -p "$repo/src"
out="$(cj start --prompt "$WORK/brief.md" --cd "$repo/src" --mode task)"; rc=$?
check "task refuses a subdirectory of the main checkout" [ "$rc" = 1 ]

amp="$WORK/R&D"; mkdir -p "$amp"
run_job --prompt "$WORK/brief.md" --cd "$amp"
check "path with & is written literally into the prompt" grep -qF "directory is $amp." "$job/prompt.md"

reset_env; allow_full; export FAKE_CODEX_MODE=noisy
run_job --prompt "$WORK/brief.md" --cd "$repo"
check "sandbox_apply text in a successful command is not a blind run" lacks 'failed with sandbox errors'

reset_env; allow_full; export FAKE_SANDBOX_SLEEP=3
before="$(ls "$CODEX_JOBS_DIR" | wc -l)"
cj start --prompt "$WORK/brief.md" --cd "$repo" --name initrace > "$WORK/start.out" 2>&1 &
sp=$!
for n in 1 2 3 4 5 6 7 8 9 10; do j="$(ls -d "$CODEX_JOBS_DIR"/*initrace* 2>/dev/null | head -1)"; [ -n "$j" ] && break; sleep 0.3; done
out="$(cj status "$j")"
check "status during setup reports started" has '^state: started$'
wait "$sp"; out="$(cj wait "$j" --max 20)"
check "job observed during setup still finishes done" has '^state: done$'

reset_env; allow_full; export FAKE_SANDBOX_SLEEP=3
cj start --prompt "$WORK/brief.md" --cd "$repo" --name cancelrace > "$WORK/start.out" 2>&1 &
sp=$!
for n in 1 2 3 4 5 6 7 8 9 10; do j="$(ls -d "$CODEX_JOBS_DIR"/*cancelrace* 2>/dev/null | head -1)"; [ -n "$j" ] && break; sleep 0.3; done
out="$(cj cancel "$j")"
check "cancel during setup reports cancelled" has '^state: cancelled$'
wait "$sp"; sleep 2
check "cancelled during setup: Codex never ran" bash -c "! grep -q '^exec' '$FAKE_CODEX_LOG'"
out="$(cj status "$j")"
check "cancelled during setup stays cancelled" has '^state: cancelled$'

reset_env; allow_full; export FAKE_SANDBOX_SLEEP=2 FAKE_CODEX_MODE=slow FAKE_CODEX_SLEEP=30
cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task --name racer1 > "$WORK/r1.out" 2>&1 &
p1=$!
cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task --name racer2 > "$WORK/r2.out" 2>&1 &
p2=$!
wait "$p1"; r1=$?; wait "$p2"; r2=$?
check "two simultaneous tasks in one worktree: exactly one starts" [ $((r1 + r2)) = 1 ]
for f in "$WORK/r1.out" "$WORK/r2.out"; do j="$(sed -n 's/^job: //p' "$f")"; [ -n "$j" ] && cj cancel "$j" > /dev/null; done

reset_env; export FAKE_SANDBOX_OK=1
run_job --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task --sandbox read-only
first="$job"; : > "$FAKE_CODEX_LOG"
run_job_resume "$first"
check "resume keeps an explicitly narrowed sandbox" grep -q 'sandbox_mode="read-only"' "$FAKE_CODEX_LOG"

# --- round-2 Opus regressions
reset_env; allow_full; export FAKE_SANDBOX_ERR="error: unrecognized subcommand 'sandbox'"
out="$(cj start --prompt "$WORK/brief.md" --cd "$repo")"; rc=$?
check "probe failing for another reason: no full access, even with the allow file" [ "$rc" = 1 ]
check "that refusal shows the probe error" has 'unrecognized subcommand'
echo any-probe-failure > "$XDG_CONFIG_HOME/codex-job/allow-full"
run_job --prompt "$WORK/brief.md" --cd "$repo"
check "allow file with any-probe-failure: full access" has '^sandbox: danger-full-access$'

reset_env; allow_full; export FAKE_CODEX_MODE=slow FAKE_CODEX_SLEEP=60
job="$(cj start --prompt "$WORK/brief.md" --cd "$repo" | field job)"
kill -KILL "$(cat "$job/runner.pid")"; sleep 1
out="$(cj wait "$job" --max 10)"
check "killed runner: job failed" has '^state: failed$'
sleep 1; check "killed runner: Codex stopped too" fake_gone

reset_env; allow_full; export FAKE_CODEX_MODE=stubborn FAKE_CHILD_PIDFILE="$WORK/child.pid"
job="$(cj start --prompt "$WORK/brief.md" --cd "$repo" | field job)"
out="$(cj cancel "$job")"; sleep 1
check "cancel stops a child that ignores TERM" bash -c "! kill -0 \$(cat '$WORK/child.pid') 2>/dev/null"
check "cancel stops a Codex that ignores TERM" fake_gone
unset FAKE_CHILD_PIDFILE

reset_env; allow_full
cp -R "$HERE/../skills/calling-codex" "$WORK/noexec"; chmod -x "$WORK/noexec/scripts/codex-job"
out="$("$BASH_BIN" "$WORK/noexec/scripts/codex-job" start --prompt "$WORK/brief.md" --cd "$repo")"
job="$(printf '%s\n' "$out" | field job)"; out="$("$BASH_BIN" "$WORK/noexec/scripts/codex-job" wait "$job" --max 20)"
check "works without the executable bit" has '^state: done$'

cj wait "$job" --max abc > /dev/null 2>&1; check "wait --max must be a number" [ $? = 2 ]
cj start --prompt "$WORK/brief.md" --cd "$repo" --watch "$WORK/nope" > /dev/null 2>&1; check "--watch of a missing dir is a usage error" [ $? = 2 ]

printf 'x' > "$repo/fifo-test" && rm "$repo/fifo-test" && mkfifo "$repo/a-fifo"
run_job --prompt "$WORK/brief.md" --cd "$repo"
check "an untracked FIFO does not hang the fingerprint" has '^state: done$'
rm -f "$repo/a-fifo"

# --- round-3 Codex regressions
reset_env
bad_jobs="$WORK/out$(printf '\n--dangerously-bypass-approvals-and-sandbox')"
CODEX_JOBS_DIR="$bad_jobs" "$BASH_BIN" "$JOB_SCRIPT" start --prompt "$WORK/brief.md" --cd "$repo" > /dev/null 2>&1; rc=$?
check "newline in CODEX_JOBS_DIR rejected" [ "$rc" = 2 ]
check "no codex run with an injected jobs dir" bash -c "! grep -q dangerously '$FAKE_CODEX_LOG'"
nl=$'\n'; mkdir -p "$WORK/actual" "$WORK/actual${nl}second"; ln -s "$WORK/actual${nl}second" "$WORK/nl-link"
cj start --prompt "$WORK/brief.md" --cd "$WORK/nl-link" > /dev/null 2>&1; rc=$?
check "symlink to a path with a newline rejected" [ "$rc" = 2 ]

reset_env; allow_full
run_job --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task      # leaves a finished holder
for round in 1 2 3; do
  export FAKE_CODEX_MODE=slow FAKE_CODEX_SLEEP=30
  cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task --name take1 > "$WORK/t1.out" 2>&1 & p1=$!
  cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task --name take2 > "$WORK/t2.out" 2>&1 & p2=$!
  wait "$p1"; r1=$?; wait "$p2"; r2=$?
  check "taking over a finished holder, round $round: exactly one task starts" [ $((r1 + r2)) = 1 ]
  for f in "$WORK/t1.out" "$WORK/t2.out"; do j="$(sed -n 's/^job: //p' "$f")"; [ -n "$j" ] && cj cancel "$j" > /dev/null; done
  unset FAKE_CODEX_MODE FAKE_CODEX_SLEEP
done

reset_env; allow_full; export FAKE_CODEX_MODE=stubborn FAKE_CHILD_PIDFILE="$WORK/child.pid"
job="$(cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task --timeout 2 | field job)"
sleep 4                                   # timed out; cleanup (TERM, 5 s, KILL) still running
out="$(cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task)"; rc=$?
check "no second task while a timed-out one is still stopping" [ "$rc" = 1 ]
out="$(cj wait "$job" --max 30)"
check "timed-out job reported once its processes are gone" has '^state: timed-out$'
check "...and Codex really is gone" fake_gone
check "...and its child too" bash -c "! kill -0 \$(cat '$WORK/child.pid') 2>/dev/null"

reset_env; allow_full; export FAKE_CODEX_MODE=stubborn FAKE_CHILD_PIDFILE="$WORK/child.pid"
job="$(cj start --prompt "$WORK/brief.md" --cd "$repo" --timeout 2 | field job)"
sleep 3; kill -KILL "$(cat "$job/runner.pid")"    # runner dies in the middle of its timeout cleanup
out="$(cj cancel "$job")"
check "cancel cleans up after a runner killed mid-cleanup" fake_gone
check "...including the child" bash -c "! kill -0 \$(cat '$WORK/child.pid') 2>/dev/null"

reset_env; allow_full; export FAKE_CODEX_MODE=slow FAKE_CODEX_SLEEP=60
job="$(cj start --prompt "$WORK/brief.md" --cd "$repo" | field job)"
ln -sn timed-out "$job/final"; kill -KILL "$(cat "$job/runner.pid")"   # crash right after claiming
out="$(cj wait "$job" --max 30)"
check "claim without the rest of finalize: still settles" has '^state: timed-out$'
check "...and Codex is stopped" fake_gone
unset FAKE_CHILD_PIDFILE

reset_env; allow_full; mkdir -p "$WORK/relw"
job="$(cd "$WORK" && cj start --prompt "$WORK/brief.md" --cd "$repo" --watch relw | field job)"
cj wait "$job" --max 20 > /dev/null
check "relative --watch saved as an absolute path" grep -qx "$WORK/relw" "$job/watch.list"

# --- round-4 Codex regressions
reset_env; allow_full
run_job --prompt "$WORK/brief.md" --cd "$repo"; old="$job"
perl -e 'use POSIX qw(setsid); setsid(); sleep 60' & bystander=$!
sleep 1; echo "$bystander" > "$old/runner.pid"; echo 1000 > "$old/ended_at"; echo 1000 > "$old/heartbeat"
rm -f "$old/gone"                                     # an old job whose number was later reused
out="$(cj status "$old")"; cj status > /dev/null; cj cancel "$old" > /dev/null
check "old job never signals a process that reused its pid" kill -0 "$bystander"
{ kill "$bystander"; wait "$bystander"; } 2>/dev/null

reset_env; allow_full; shim="$WORK/shim"; mkdir -p "$shim"
cat > "$shim/mv" <<'SHIM'
#!/bin/bash
case "${2:-}" in *.owner) kill -KILL "$PPID" ;; esac   # die just before publishing the claim
exec /bin/mv "$@"
SHIM
chmod +x "$shim/mv"
out="$(PATH="$shim:$PATH" cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task)"; rc=$?
check "a claim that died before it was recorded fails the start" [ "$rc" = 1 ]
check "...and Codex never ran" bash -c "! grep -q '^exec' '$FAKE_CODEX_LOG'"

reset_env; allow_full; export FAKE_CODEX_MODE=stubborn FAKE_CHILD_PIDFILE="$WORK/child.pid"
job="$(cj start --prompt "$WORK/brief.md" --cd "$repo" --timeout 2 | field job)"
for n in 1 2 3 4 5 6 7 8 9 10; do [ -L "$job/final" ] && break; sleep 0.5; done
export FAKE_CODEX_MODE=slow FAKE_CODEX_SLEEP=30
out="$(cj resume "$job" --prompt "$WORK/follow.md")"; rc=$?
check "no follow-up while the original turn is still stopping" [ "$rc" = 1 ]
cj wait "$job" --max 30 > /dev/null; unset FAKE_CHILD_PIDFILE

reset_env; allow_full; export FAKE_CODEX_MODE=blind-bwrap
run_job --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task
check "task whose commands all failed (bwrap): warned" has 'every command Codex ran failed'
check "...and flagged as a sandbox failure" has 'failed with sandbox errors'
first="$job"; run_job_resume "$first"
check "follow-up whose commands all failed: warned" has 'every command Codex ran failed'

reset_env; allow_full; mkdir -p "$WORK/elsewhere"
out="$(cd "$WORK/elsewhere" && CODEX_JOBS_DIR=reljobs "$BASH_BIN" "$JOB_SCRIPT" start --prompt "$WORK/brief.md" --cd "$repo")"
job="$(printf '%s\n' "$out" | field job)"
out="$(CODEX_JOBS_DIR=/unused "$BASH_BIN" "$JOB_SCRIPT" wait "$job" --max 20)"
check "relative CODEX_JOBS_DIR works when --cd is elsewhere" has '^state: done$'

# --- a turn the backend declines is a failure with its reason shown
reset_env; allow_full; export FAKE_CODEX_MODE=refused
run_job --prompt "$WORK/brief.md" --cd "$repo"
check "declined turn: failed" has '^state: failed$'
check "declined turn: reason shown" has '^codex_error: This content was flagged'

# --- round-5 Codex regressions
reset_env; allow_full; export FAKE_CODEX_MODE=closefd FAKE_CHILD_PIDFILE="$WORK/child.pid"
job="$(cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task | field job)"
sleep 2
out="$(cj start --prompt "$WORK/brief.md" --cd "$WORK/wt" --mode task)"; rc=$?
check "child without the lock fd still blocks a second task" [ "$rc" = 1 ]
out="$(cj wait "$job" --max 30)"
check "child without the lock fd: job settles done" has '^state: done$'
check "...and that child was stopped" bash -c "! kill -0 \$(cat '$WORK/child.pid') 2>/dev/null"
unset FAKE_CHILD_PIDFILE

reset_env; allow_full
run_job --prompt "$WORK/brief.md" --cd "$repo"; legacy="$job"
perl -e 'use POSIX qw(setsid); setsid(); sleep 60' & bystander=$!
sleep 1; rm -f "$legacy/alive.lock" "$legacy/gone"; echo "$bystander" > "$legacy/runner.pid"; echo 1000 > "$legacy/ended_at"
cj status "$legacy" > /dev/null; cj status > /dev/null; cj cancel "$legacy" > /dev/null
check "job from an older version never signals a reused pid" kill -0 "$bystander"

run_job --prompt "$WORK/brief.md" --cd "$repo"; stale="$job"
rm -f "$stale/final" "$stale/gone"; echo running > "$stale/state"           # runner died unobserved...
echo "$bystander" > "$stale/runner.pid"; echo 1000 > "$stale/heartbeat"     # ...long ago; pid since reused
out="$(cj status "$stale")"
check "long-dead runner: job settles failed" has '^state: failed$'
check "...without signalling the process that reused its pid" kill -0 "$bystander"
check "...and says why it left that group alone" has 'too long after the job'
{ kill "$bystander"; wait "$bystander"; } 2>/dev/null

reset_env; allow_full; export FAKE_CODEX_MODE=stubborn FAKE_CHILD_PIDFILE="$WORK/child.pid"
job="$(cj start --prompt "$WORK/brief.md" --cd "$repo" --timeout 2 | field job)"
for n in 1 2 3 4 5 6 7 8 9 10; do [ -L "$job/final" ] && break; sleep 0.5; done
export FAKE_CODEX_MODE=ok
out="$(CODEX_JOBS_DIR="$WORK/other-jobs" "$BASH_BIN" "$JOB_SCRIPT" resume "$job" --prompt "$WORK/follow.md")"; rc=$?
check "follow-up from another jobs dir still waits for the original to stop" [ "$rc" = 1 ]
cj wait "$job" --max 30 > /dev/null; unset FAKE_CHILD_PIDFILE

# --- round-6: cancel must KILL a TERM-ignoring child that dropped the lock fd
reset_env; allow_full; export FAKE_CODEX_MODE=closefd-stubborn FAKE_CHILD_PIDFILE="$WORK/child.pid"
job="$(cj start --prompt "$WORK/brief.md" --cd "$repo" | field job)"
sleep 2; out="$(cj cancel "$job")"
check "cancel kills a TERM-ignoring child outside the lock" bash -c "! kill -0 \$(cat '$WORK/child.pid') 2>/dev/null"
check "no half-written timestamps left behind" bash -c "! ls '$job'/*.tmp.* 2>/dev/null | grep -q ."
unset FAKE_CHILD_PIDFILE

echo "---"; echo "passed: $pass  failed: $fail  (bash $("$BASH_BIN" -c 'echo $BASH_VERSION'))"
rm -rf "$WORK"
[ "$fail" = 0 ]
