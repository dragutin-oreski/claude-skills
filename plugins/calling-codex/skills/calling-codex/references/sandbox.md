# Codex and sandboxes

## What goes wrong

Codex confines every shell command it runs with its own sandbox: `sandbox-exec` (Seatbelt)
on macOS, Landlock/bubblewrap on Linux. Claude Code can also run its Bash tool in a sandbox.
On macOS a process that is already sandboxed cannot apply a second Seatbelt profile, so
inside a sandboxed Claude Code **every** command Codex tries fails:

```
sandbox-exec: sandbox_apply: Operation not permitted
```

Codex reads files through shell commands, so it can then read nothing. It still answers,
from the brief alone, and the answer looks like a real review. That is the dangerous part:
a confident review of code it never opened.

You can check directly: `codex sandbox -- /bin/sh -c true` exits 0 when Codex's sandbox works
and fails (exit 71 on macOS) when it cannot start.

## What codex-job does

On every `start` it runs that probe.

| Probe | Request | Result |
|---|---|---|
| works | `--sandbox auto` (default) | Codex's own sandbox: `read-only` for review modes, `workspace-write` for task |
| works | `--sandbox read-only` / `workspace-write` | that mode |
| fails with the nested-sandbox error | `auto`, and a human allowed full access | `danger-full-access` |
| fails with the nested-sandbox error | `auto`, not allowed | refused, with the command a human can run to allow it |
| fails for any other reason | `auto` | refused, showing the probe error (unless the allow file says `any-probe-failure`) |
| fails | `read-only` / `workspace-write` | refused (it would be blind) |

"The nested-sandbox error" is `sandbox_apply: Operation not permitted` (macOS Seatbelt
refusing to nest). Other failures — an unknown `codex sandbox` syntax in a different Codex
version, bubblewrap blocked by AppArmor on Ubuntu, a container without user namespaces — do
not prove an outer sandbox, so they never unlock full access on their own. If you run in a
container you trust as the boundary, put the line `any-probe-failure` in the allow file.

There is no flag that asks for full access directly. Full access is only used when Codex's
own sandbox cannot start, which in practice means an outer sandbox is already in place.

The human permission is either:

```bash
mkdir -p ~/.config/codex-job && touch ~/.config/codex-job/allow-full   # persistent
export CODEX_JOB_ALLOW_FULL=1                                          # per shell
echo any-probe-failure > ~/.config/codex-job/allow-full                # also when the probe fails otherwise
```

`$XDG_CONFIG_HOME` is honoured instead of `~/.config` when set.

Your outer sandbox must let the agent **read** the allow file. Many sandbox profiles close
most of `~/.config`. Then the file is invisible from inside, and `start` keeps refusing even
after you created it. A quick check from inside the sandboxed session: `ls ~/.config/codex-job`
says "Operation not permitted". Grant read access to that one file and nothing else, and never
write access, or the agent could create its own permission. For a macOS Seatbelt profile, add
this after the rule that closes `~/.config`, since the last matching rule wins:

```scheme
(allow file-read* (literal "/Users/YOU/.config/codex-job/allow-full"))
```

A profile is fixed when the sandbox starts, so restart the sandboxed session afterwards.

## Is full access safe?

Only when something else contains Codex. Inside a sandboxed Claude Code, the outer sandbox
limits what any command can write and reach, whichever program runs it; that is why the
probe failing is a reasonable signal. Without an outer sandbox, full access lets Codex write
anywhere your user can. That is why it needs a human's permission, and why an agent must
never grant it.

Full access also means the job rules ("read-only", "change files only inside the worktree")
are instructions to Codex, not enforcement. `codex-job` checks afterwards: it fingerprints
the directories a job must not change (the reviewed checkout; for tasks, the main checkout)
and reports `warning: tree changed: <dir>` if they changed. This is best-effort detection
of net changes, not enforcement: it covers HEAD, staged and unstaged edits, untracked files,
refs and local git config, but not git-ignored files, directories nobody watched, or a change
that was made and undone. It also cannot tell Codex's edits from yours if you edit the same
checkout while a job runs. Add `--watch DIR` for other directories that matter.

## Processes

Each job runs in its own process session. `cancel` and the timeout stop Codex and every
process it started, unless one of those started its own session (a daemon or a dev server
that detaches); stop those by hand. Jobs keep running if Claude Code exits, up to their
`--timeout`.

How it knows: the job's supervisor holds a lock that Codex and its children inherit, so a held
lock proves a job process is alive. Children that close inherited files (Python's subprocess
does) are found through the job's process group, which is trusted only within 10 minutes of
the supervisor's last heartbeat, because a process-group number can be reused once the group
is gone. Outside that window nothing is signalled automatically; `status` prints the
`kill -- -<number>` command for a human to run if the group is the job's.

A job counts as finished only when its final state is recorded **and** none of its processes
is left. `wait` keeps waiting until then; processes still alive 10 s after the job ended (a
background server Codex left running, or a supervisor killed mid-cleanup) are stopped by the
next `wait`, `status`, `cancel` or task start. Until then, a new task in the same worktree is
refused.

## Codex sandbox and git worktrees

In `workspace-write`, Codex can write only inside its working directory. A linked worktree
keeps its git index under the main checkout's `.git/worktrees/`, outside that area, so
`git add` and `git commit` fail there. The task rules therefore tell Codex not to stage or
commit; the calling agent reviews the uncommitted changes.
