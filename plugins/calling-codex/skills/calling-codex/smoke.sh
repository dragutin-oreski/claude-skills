#!/usr/bin/env bash
# Connectivity smoke test for Codex.
# Verifies the `codex` CLI can authenticate and reach its backend.
# The MCP server (mcp__codex__codex) shares the same auth + TLS path,
# so if this passes, the MCP tool works too.
#
# Usage: bash .claude/skills/calling-codex/smoke.sh
set -euo pipefail

# Codex needs an explicit root-CA bundle on this machine, or its TLS
# handshake to the ChatGPT backend fails with "no native root CA
# certificates found". The MCP registration already carries this; the
# CLI needs it in the environment.
export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/cert.pem}"

echo "codex: $(command -v codex)"
codex --version
echo "auth: $(codex login status 2>&1 | tail -1)"
echo "--- live call (default model, read-only) ---"
codex exec --sandbox read-only --skip-git-repo-check "Reply with exactly: smoke-ok" 2>&1 | tail -3
