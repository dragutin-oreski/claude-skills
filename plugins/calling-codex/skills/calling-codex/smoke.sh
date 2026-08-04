#!/usr/bin/env bash
# Connectivity smoke test for Codex.
# Verifies the `codex` CLI can authenticate and reach its backend.
# The MCP server (mcp__codex__codex) shares the same auth + TLS path,
# so if this passes, the MCP tool works too.
#
# Run from a plain terminal. Inside a sandboxed Claude Code session the
# default read-only mode fails on macOS (nested sandbox — see SKILL.md);
# there, run:  CODEX_SMOKE_SANDBOX=danger-full-access bash smoke.sh
#
# Usage: bash smoke.sh   (from this skill's directory)
set -euo pipefail

# Some setups need an explicit root-CA bundle, or Codex's TLS handshake
# to its backend fails with "no native root CA certificates found"
# (diagnose with `codex doctor`). Harmless where not needed.
if [[ -z "${SSL_CERT_FILE:-}" && -f /etc/ssl/cert.pem ]]; then
  export SSL_CERT_FILE=/etc/ssl/cert.pem
fi

SANDBOX_MODE="${CODEX_SMOKE_SANDBOX:-read-only}"

echo "codex: $(command -v codex)"
codex --version
echo "auth: $(codex login status 2>&1 | tail -1)"
echo "--- live call (default model, --sandbox $SANDBOX_MODE) ---"
codex exec --sandbox "$SANDBOX_MODE" --skip-git-repo-check "Reply with exactly: smoke-ok" 2>&1 | tail -3
