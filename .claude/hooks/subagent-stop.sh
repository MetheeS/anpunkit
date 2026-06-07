#!/usr/bin/env bash
# SubagentStop hook.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

mkdir -p docs/.snapshots
LOG="docs/.snapshots/agent-trace.log"
echo "$(date +%H:%M:%S) subagent finished" >> "$LOG"

tail -n 50 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" || true
exit 0
