#!/usr/bin/env bash
# PreCompact hook. Fires before auto/manual /compact.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

mkdir -p docs/.snapshots
STAMP=$(date +%Y%m%d-%H%M%S)
SNAP="docs/.snapshots/precompact-${STAMP}.md"

{
  echo "# Pre-compact snapshot ${STAMP}"
  echo
  echo "## Git"
  git status --short 2>/dev/null || true
  git diff --stat 2>/dev/null || true
  echo
  echo "## STATE.md at compact time"
  [ -f docs/STATE.md ] && cat docs/STATE.md || echo "(no STATE.md)"
} > "$SNAP"

ls -1t docs/.snapshots/precompact-*.md 2>/dev/null | tail -n +6 | xargs -r rm -f

echo "Context was compacted. Recovery snapshot saved at ${SNAP}."
echo "STATE.md and ISSUES.md were re-injected by the SessionStart hook - trust those."
exit 0
