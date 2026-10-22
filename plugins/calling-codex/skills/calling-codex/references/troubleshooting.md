# Troubleshooting codex-job

| What you see | Cause | Fix |
|---|---|---|
| `start` → failed, "already inside a sandbox" | Nested sandbox (see sandbox.md) | Ask the human to allow full access, or run outside the sandbox |
| `start` → failed, "for a reason other than a nested sandbox" | Codex's sandbox is broken or unsupported here | Run `codex sandbox -- /bin/sh -c true` to see why; see sandbox.md for containers |
| failed with network, permission or `~/.codex` write errors under Claude Code's built-in `/sandbox` | Codex needs to write `~/.codex` (sessions, auth) and reach OpenAI | Add `~/.codex` to the sandbox's writable paths and OpenAI's API hosts to its network allowlist |
| `done` + `warning: … sandbox_apply errors` or `no successful commands` | Codex could not run commands, so it read nothing | Treat as unverified; fix the sandbox, re-run |
| failed, `not logged in` / 401 | Codex auth expired | The user runs `codex login` |
| failed, `no native root CA certificates found`, or TLS errors | No CA bundle visible to Codex | Set `SSL_CERT_FILE` to a CA bundle (codex-job uses `/etc/ssl/cert.pem` when present) |
| failed, `stream disconnected before completion` | Network or backend drop | Retry once; for a task, check the worktree first |
| failed, "did not finish its turn" | Codex exited mid-turn (limit reached, crash) | Read `stderr.log` in the job dir; retry or narrow the brief |
| failed, "did not report a thread within 60s" | Codex could not start (auth, network, config) | Run `codex exec "say ok"` by hand to see the error |
| failed, "runner exited without a final state" | Job was killed from outside, or the machine slept | Re-run |
| `timed-out` | Hit `--timeout` (default 1800 s) | Narrow the brief or raise `--timeout` |
| `warning: Codex processes of this job are still stopping` | Job ended but its processes have not exited yet | `wait` again; they are stopped within ~10 s |
| `wait` returns `running` again and again | Large review, or high reasoning effort | Keep waiting, or `cancel` and narrow the brief |
| `warning: tree changed: <dir>` | A job wrote where it must not, or you edited meanwhile | `git -C <dir> status`; tell the user before anything else |
| failed, "another task job is running in …" | One task per worktree at a time | `wait` for or `cancel` the other job, or use a second worktree |
| failed, "another follow-up on this Codex thread is running" | One turn per thread at a time | `wait` for it first |
| usage error, "must not contain line breaks" | A path, name or model contained a newline (job files are one value per line) | Rename or move the file |
| `codex: command not found` | Codex not installed / not on PATH | `npm install -g @openai/codex` (or Homebrew); set `CODEX_BIN` if elsewhere |
| `/mcp` shows codex failing to connect | Old MCP registration (`codex mcp-server` was removed in 0.154) | `claude mcp remove codex` (add `-s user` or `-s local` to match where it was added) |

## Job directory

Each job is a directory under `$CODEX_JOBS_DIR` (default `$TMPDIR/codex-jobs`):

| File | Holds |
|---|---|
| `prompt.md` | exactly what was sent to Codex |
| `events.jsonl` | Codex's event stream (`codex exec --json`) |
| `stderr.log` | Codex's stderr plus codex-job's own notes |
| `result.md` | Codex's final message |
| `meta`, `state`, `exit_code`, `argv` | job settings, current state, Codex's exit code, the exact argv |
| `tree.N.dir` / `tree.N.hash` | directories the job must not change, with their fingerprints |

## Platform notes

- Tested on macOS (bash 3.2 and 5.x). Linux should work (uses `setsid`); Windows only
  under WSL. Needs `setsid` or `perl`, and `flock` or `perl` (macOS has perl; Linux has
`setsid` and `flock` from util-linux).
- Model and reasoning effort come from `~/.codex/config.toml` unless you pass
  `--model` / `--effort`.
