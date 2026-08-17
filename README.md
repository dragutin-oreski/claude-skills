# claude-skills

Battle-tested [Claude Code](https://claude.com/claude-code) skills, extracted from daily
use on a multi-repo clinical health platform and generalized for any project.

## What's inside

| Skill | What it does |
|-------|--------------|
| [`explain-diff`](plugins/explain-diff/skills/explain-diff/SKILL.md) | Turns a ticket, branch, or commit range into a **visual HTML review explainer**: background before diff, one interactive walker for the change's core mechanism, a literate walkthrough in *execution* order, a cross-repo readiness verdict, and a 5-question sign-off quiz. Implements Geoffrey Litt's "explain diff" / speed-regulator pattern — don't pass the code along until you can pass the quiz. Ships with the HTML design template. |
| [`calling-codex`](plugins/calling-codex/skills/calling-codex/SKILL.md) | Delegates tasks to OpenAI Codex from inside Claude Code via the `codex` MCP server. Has the painful parts already solved: the `codex mcp-server` vs `codex mcp` registration trap, the macOS **nested-sandbox** failure (why `read-only` makes Codex file-blind and when `danger-full-access` is actually the safe choice), the root-CA/TLS fix, multi-turn threads, and a smoke test. |
| [`writing-goal-prompts`](plugins/goal-prompts/skills/writing-goal-prompts/SKILL.md) | Authors **resumable** prompts for Claude Code's `/goal` command. Encodes the four mechanics that dictate the design (the evaluator only sees the transcript; state must live in files; the 4000-char limit; resume resets counters) plus templates and a validator script, so long-running goals survive interruption instead of restarting. |
| [`design-loop`](plugins/design-loop/skills/design-loop/SKILL.md) | Designs (never runs) **engineered loops** for long-running agent work — the "loop engineering" pattern as a method. Produces a three-file *loop pack*: a **contract** (outcome as evidence not activity, four-class decision rights with delegable-but-default-queued outward actions, budgets a fresh dispatcher can enforce from disk, five terminal stop reasons, typed gate effects), a crash-safe **ledger** (wall-clock lease lock, reserve-first dispatch, dirty orphans quarantined never deleted), and a **tick prompt**. Ships a validator (`check-loop.sh`) and a deterministic HTML pack renderer (`render_pack.py`). Hardened by two independent adversarial reviews — five blockers found and folded before v1 ever ran. |

## Install

### As plugins (recommended)

```
/plugin marketplace add dragutin-oreski/claude-skills
/plugin install explain-diff@claude-skills
/plugin install calling-codex@claude-skills
/plugin install goal-prompts@claude-skills
/plugin install design-loop@claude-skills
```

Plugin names and skill names differ in one case: installing the **goal-prompts**
plugin gives you the **writing-goal-prompts** skill.

### Manual copy

Copy any `plugins/<name>/skills/<skill>/` directory into your project's
`.claude/skills/` (per-project) or `~/.claude/skills/` (everywhere):

```bash
mkdir -p ~/.claude/skills
cp -R plugins/explain-diff/skills/explain-diff ~/.claude/skills/
```

## Usage

- `/explain-diff TICKET-123` (or "explain this branch/diff") — produces the explainer
  as a local HTML page; where the Artifact tool is available it also publishes it as a
  private Artifact.
- "Ask codex for a second opinion on this change" — invokes `calling-codex`.
- "Write a goal prompt for migrating X" — invokes `writing-goal-prompts`, which produces
  a validated `GOAL.md` you paste after `/goal`.

## On skill length

These skills are intentionally *not* minimal. The current advice to keep skills short
applies to what loads into every session — the frontmatter `description` — and to
generic filler in the body. The body only loads when the skill fires, and everything in
these bodies is operational specifics you'd otherwise re-learn the hard way (sandbox
traps, evaluator mechanics, quality bars). Heavy assets (the HTML template, goal
templates) live in subdirectories and load only when read — progressive disclosure.

## License

MIT
