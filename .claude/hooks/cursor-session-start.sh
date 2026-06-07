#!/usr/bin/env bash
# cursor-session-start.sh — Cursor wiring for the SESSION-OPEN ritual.
# Cursor's sessionStart hook expects JSON on stdout ({"additional_context": ...}),
# unlike Claude Code, which injects raw stdout. This wrapper runs the SHARED
# session-start.sh body (single copy — anti-drift) and wraps its output in the
# JSON envelope Cursor requires. Cursor sets CLAUDE_PROJECT_DIR (compat alias),
# so the shared script needs no changes.
# Uses node for JSON (the kit assumes Node; python3 is a fallback only).
# Verified against cursor.com/docs/hooks (sessionStart output schema), 2026-06.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(bash "$HERE/session-start.sh" 2>/dev/null || true)"
if command -v node >/dev/null 2>&1; then
  printf '%s' "$OUT" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>console.log(JSON.stringify({additional_context:d})))'
else
  printf '%s' "$OUT" | python3 -c 'import json,sys; print(json.dumps({"additional_context": sys.stdin.read()}))'
fi
