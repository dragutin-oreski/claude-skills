---
name: calling-codex
description: How to call, invoke, or delegate a task to Codex (OpenAI Codex CLI / GPT-5) from Claude Code via the codex MCP server. Use when asked to "ask codex", "call codex", "delegate to codex", "get a second opinion from codex", or run a coding task through Codex. Covers registration, sandbox pitfalls, full-access invocation, and multi-turn replies.
---

# Calling Codex

Codex (OpenAI's CLI agent) is driven from Claude Code as the **`codex` MCP
server** — two tools, not a shell command:

- `mcp__codex__codex` — start a new Codex session (returns a `threadId`).
- `mcp__codex__codex-reply` — continue an existing session by `threadId`.

> Tool schemas may be **deferred**. Before the first call, load them:
> `ToolSearch` with query `select:mcp__codex__codex,mcp__codex__codex-reply`.

## One-time setup

Requires the `codex` CLI installed and logged in (`codex login`). Register it
as an MCP server — the subcommand must be `mcp-server`:

```bash
claude mcp add codex -- codex mcp-server
```

If Codex later fails with "no native root CA certificates found" or streams
disconnect mid-call (diagnose with `codex doctor`), it can't find a root-CA
bundle — re-register with one passed explicitly:

```bash
claude mcp remove codex -s local
claude mcp add codex -e SSL_CERT_FILE=/etc/ssl/cert.pem -- codex mcp-server
```

## Invocation rules

1. **Use the default model.** Don't pass the `model` parameter — omitting it
   uses Codex's configured default.
2. **When Claude Code runs sandboxed (macOS), full access is required, not
   just allowed:**
   - `sandbox: "danger-full-access"`
   - `approval-policy: "never"`

   Why: `read-only` and `workspace-write` make Codex confine each command with
   macOS `sandbox-exec`, but macOS refuses to nest a sandbox inside Claude
   Code's — so **every** command (even a bare `printf ok` or a file read) dies
   with `sandbox-exec: sandbox_apply: Operation not permitted`, and Codex
   becomes file-blind. `danger-full-access` adds no confinement to nest, so
   commands run directly. It is safe there because Claude Code's outer sandbox
   is the real boundary. (If Claude Code is *not* sandboxed, prefer
   `workspace-write` — full access would then be genuinely unconfined.)
3. **Set `cwd`** to the directory Codex should work in when the task touches
   files. Codex resolves relative paths against it.

## Call it

**Inside a sandboxed Claude Code (macOS)** — full access is required (rule 2;
Claude Code's outer sandbox is the boundary):

```
mcp__codex__codex(
  prompt: "<the task for codex>",
  sandbox: "danger-full-access",
  approval-policy: "never",
  // no `model` → default model
  // cwd: "<abs path>" when codex should operate on files
)
```

**Unsandboxed Claude Code, or unsure** — there is no outer boundary, so keep
Codex confined:

```
mcp__codex__codex(
  prompt: "<the task for codex>",
  sandbox: "workspace-write",
  // cwd: "<abs path>" when codex should operate on files
)
```

If the workspace-write call fails with `sandbox-exec: sandbox_apply: Operation
not permitted`, you *are* inside a sandbox — switch to the first form.

Returns JSON: `{"threadId": "...", "content": "<codex's reply>"}`.

### Continue the conversation

Reuse the `threadId` — Codex keeps context across turns:

```
mcp__codex__codex-reply(
  threadId: "<from the first response>",
  prompt: "<follow-up>"
)
```

## Connectivity check (CLI path — secondary)

To confirm Codex is reachable without going through the MCP tool (useful when
the MCP status shows "Failed to connect"). Run it from a plain terminal — its
default `read-only` mode is exactly what fails inside a sandboxed Claude Code
session (rule 2); in that case run it with `CODEX_SMOKE_SANDBOX=danger-full-access`:

```bash
bash smoke.sh   # in this skill's directory
```

Expected tail: `Logged in using ChatGPT` and a final line `smoke-ok`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/mcp` shows `Failed to reconnect to codex: -32000` | Registered with the wrong subcommand — must be `codex mcp-server` (Codex *as* a server), not `codex mcp` (which only manages other MCP servers). `claude mcp remove codex -s local`, then re-add as in Setup. |
| `stream disconnected before completion ... backend-api` | If `codex doctor` shows a certificate error ("no native root CA certificates found"), re-register with `SSL_CERT_FILE=/etc/ssl/cert.pem`. Otherwise it's likely transient — see the long-tasks note before retrying. |
| `codex doctor` → `reachability ... connect failed` | Same CA issue; also check VPN/proxy/firewall. |
| Tool call fails `InputValidationError` | Schemas not loaded — run the `ToolSearch select:` query first. |
| `sandbox-exec: sandbox_apply: Operation not permitted` (Codex can't run/read anything) | Nested sandbox — you called it with `read-only`/`workspace-write` inside a sandboxed Claude Code. Switch to `sandbox: "danger-full-access"` (rule 2). |
| `Not inside a trusted directory` (CLI) | Add `--skip-git-repo-check` to `codex exec`. |

Other gotchas:

- **After re-registering, run `/mcp`** to reconnect — the tool live in the
  current session keeps the *old* process/env until you do.
- **`content` is JSON, not prose.** Parse out the `content` field; don't hand
  the raw `{"threadId":...}` string to the user.
- **Long tasks:** the call blocks until Codex finishes or the stream drops.
  On a transient `stream disconnected`, don't blindly re-send a mutating
  prompt — Codex may already have changed files. Check what landed on disk
  first, then continue via `codex-reply` on the same thread (or re-send only
  if the prompt is idempotent).
