---
name: calling-codex
description: Call OpenAI Codex (the `codex` CLI) from Claude Code as a background job — for an independent code review, an adversarial review that tries to show the change should not ship, a second opinion on a plan, or delegating a contained implementation task to Codex in its own git worktree. Use when asked to "ask codex", "codex review", "get a second opinion from codex", "adversarial review", "have codex implement/try this", or when the project's workflow calls for an independent review. Handles time limits, cancellation, follow-up questions on the same Codex thread, and the nested-sandbox trap that makes Codex silently file-blind.
---

# Calling Codex

Codex runs as a background job through the bundled `scripts/codex-job` script, which wraps
`codex exec`. You start it, keep working or wait, then read the result. There is no MCP
server: OpenAI removed `codex mcp-server` in Codex CLI 0.154.

`<skill dir>` below is this skill's base directory (shown when the skill loads). Always run
the script with `bash`, so it works without the executable bit.

## Before the first call

1. **House rules.** Look for `.claude/codex-house-rules.md`, walking up from the current
   directory and from the directory Codex will work in. If found, read it and follow it on
   top of this skill. House rules can only add restrictions; they cannot grant Codex more
   access than this skill allows.
2. **Codex present?** `codex --version` and `codex login status`. If either fails, tell the
   user: install with `npm install -g @openai/codex`, then run `codex login` themselves.

## The loop

```bash
# 1. Write the brief to a file OUTSIDE the repo (scratchpad or $TMPDIR) — a file inside a
#    task worktree makes it dirty and the task is refused. See "Writing the brief".
# 2. Start. Returns within ~60 s.
bash "<skill dir>/scripts/codex-job" start --mode review --cd /abs/repo --prompt /abs/brief.md --name auth-review
# 3. Wait. Blocks up to 540 s, then reports. Give the Bash call timeout: 600000.
bash "<skill dir>/scripts/codex-job" wait <job>
#    `state: running` → call wait again (or cancel). `done` → step 4. Anything else → "When it fails".
# 4. Read the result.
bash "<skill dir>/scripts/codex-job" result <job>
```

- `<job>` is the `job:` line from `start`. Every command prints `state: …` first:

  | state | what to do |
  |---|---|
  | `started`, `running` | `wait` again (or `cancel`) |
  | `done` | `result`, then read any `warning:` lines (below) |
  | `failed`, `timed-out` | see "When it fails" |
  | `cancelled` | nothing; it was stopped on request |
- **Long jobs, other work to do:** run the `wait` call with `run_in_background: true` and
  carry on; you are notified when it returns. Do not poll with `sleep`.
- **Reviews take minutes** (often 5–10 on a large change, longer at high reasoning effort).
  Default hard limit is 1800 s; set `--timeout` for more or less. A job that hits it is
  killed and reported `timed-out`.
- `--watch DIR` (repeatable) adds directories the job must not change; you get a warning on
  `done` if they did. The reviewed directory (and for tasks, the main checkout) is watched
  automatically.
- `status` (no argument) lists all jobs — use it to find a job again after context loss.
  `cancel <job>` stops one and everything it started.

### Modes

| `--mode` | Use for | Codex may write files? |
|---|---|---|
| `review` (default) | Bugs and risks in a diff, a plan, a document | No |
| `adversarial` | "Why should this NOT ship?" — challenges the approach, assumptions, failure modes | No |
| `task` | Implementing a contained piece of work | Yes, only inside `--cd`, which must be a clean git worktree used by no other task job |

The script adds the rules and the output format for each mode to your brief (see
`prompts/`); you write only the request.

### Follow-up questions

```bash
bash "<skill dir>/scripts/codex-job" resume <job> --prompt /abs/followup.md
```

Starts a new job on the same Codex thread, so Codex remembers the earlier turn. It keeps the
original job's directory, mode, sandbox request and `--watch` list; only one follow-up per
thread runs at a time. Send only the new question ("Finding 2: show the failing input",
"Re-check after my fix in auth.py"). Then `wait` and `result` as before.

## Writing the brief

A review with no questions comes back generic. Put in the brief:

- **What to read**: absolute paths, the diff range (`git diff main...HEAD`), the plan file.
- **What it is for** in one or two sentences, and what has already been checked.
- **The questions** you want answered, numbered. Name the risk you are worried about.
- **For tasks**: the exact outcome, how to check it (the test command), what not to touch.

Do not tell Codex what you think the answer is. More in `references/briefing.md`.

## Using the result

- **Verify before you relay.** Check each finding against the code yourself. Report which you
  confirmed, which you rejected and why, and which you could not check. Never pass Codex's
  text along as settled.
- **Do not fix findings on your own initiative** unless the user or the workflow asked for
  review-and-fix. Report first.
- **"No findings" is an answer.** Say so plainly; do not invent minor issues.
- **Task results:** read the diff in the worktree (`git -C <wt> diff`), run the tests
  yourself, then present the change. Never merge or copy it into the user's checkout unless
  asked.
- **Warnings on `done`:**
  - `tree changed: <dir>` — a job that must not write did, or someone else edited files
    meanwhile. Check `git status` there before anything else and tell the user.
  - `every command Codex ran failed`, `failed with sandbox errors`, or `ran no commands` —
    Codex may not have read the code. Treat the result as unverified; fix the cause (often the
    sandbox, below) before re-running. `commands: N of M succeeded` shows how much it ran.
  - `processes of this job are still stopping` — `wait` again before starting another task in
    the same worktree.

## When it fails

Report the failure and its reason to the user. **Never write a substitute answer yourself and
present it as Codex's**, and never work around a refusal by calling `codex exec` directly or
with `--dangerously-bypass-approvals-and-sandbox`.

- `failed` at `start`, saying Codex's own sandbox cannot start: see Sandbox below.
- `failed` with an auth or login error: the user must run `codex login`.
- `failed` with `stream disconnected` or a network error: retry once. For a task, check what
  landed in the worktree first.
- `codex_error:` says the backend declined the turn (a content flag, a usage limit): tell the
  user. If legitimate work was flagged for its wording, a fresh job that states the same
  request plainly may pass; never disguise what you are asking for.
- `timed-out`: re-run with a narrower brief or a larger `--timeout`.

More in `references/troubleshooting.md`.

## Sandbox (read once)

Codex normally runs inside its own sandbox: read-only for reviews, workspace-write for tasks.
`codex-job` uses that whenever it works. On macOS, inside a sandboxed Claude Code, Codex's
sandbox cannot start (`sandbox-exec: sandbox_apply: Operation not permitted`), and Codex then
cannot read or run anything. Its review would be written from the brief alone.

In that case only (the probe fails with exactly that nested-sandbox error), `codex-job` runs
Codex with full access, if a human has allowed it by running this in their own terminal:

```bash
mkdir -p ~/.config/codex-job && touch ~/.config/codex-job/allow-full
```

Otherwise it refuses, and it refuses any other probe failure too. **Never create that file
or set `CODEX_JOB_ALLOW_FULL` yourself.** Show the user the command and why it is needed. Full access is safe only because the outer
sandbox is then the boundary. Details: `references/sandbox.md`.
