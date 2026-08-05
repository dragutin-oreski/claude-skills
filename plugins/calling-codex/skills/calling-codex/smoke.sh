#!/usr/bin/env bash
# Connectivity smoke test for Codex.
# Verifies the `codex` CLI can authenticate and reach its backend.
# If this passes, auth + backend connectivity work — but the MCP
# registration can still be broken (wrong subcommand, or missing
# SSL_CERT_FILE in the server's own env): see SKILL.md troubleshooting.
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
  echo "note: injected SSL_CERT_FILE=/etc/ssl/cert.pem for this test only." >&2
  echo "      If that is what makes it pass, the MCP server needs the same" >&2
  echo "      variable in its registration (claude mcp add ... -e SSL_CERT_FILE=...)." >&2
fi

SANDBOX_MODE="${CODEX_SMOKE_SANDBOX:-read-only}"

echo "codex: $(command -v codex)"
codex --version
echo "auth: $(codex login status 2>&1 | tail -1)"
echo "--- live call (default model, --sandbox $SANDBOX_MODE) ---"
codex exec --sandbox "$SANDBOX_MODE" --skip-git-repo-check "Reply with exactly: smoke-ok" 2>&1 | tail -3
