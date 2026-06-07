#!/usr/bin/env bash
# regression.sh — run the cross-phase regression corpus (tests/regression/).
# The accumulated MOCK corpus is the always-on regression guard (fast,
# deterministic): run on every phase CLOSE, after /quick, after /replan.
# The REAL corpus runs only at the final phase and after /replan.
#
# Usage:
#   bash scripts/regression.sh           # mock corpus (default)
#   bash scripts/regression.sh --real    # real corpus (hits live services)
#
# mock-vs-real is a fixture/env FLAG on the SAME test, surfaced via TEST_MODE.
# Tests read TEST_MODE to decide whether to mock the external boundary.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

MODE="mock"
[ "${1:-}" = "--real" ] && MODE="real"
export TEST_MODE="$MODE"

CORPUS="tests/regression"
if [ ! -d "$CORPUS" ]; then
  echo "regression: no $CORPUS/ dir — nothing to guard yet."
  exit 0
fi

# Count corpus files (visible, auditable — no hidden marker state).
COUNT=$(find "$CORPUS" -type f \( -name '*test*' -o -name '*spec*' \) 2>/dev/null | wc -l | tr -d ' ')
echo "=== regression ($MODE) — $COUNT corpus file(s) in $CORPUS/ ==="
if [ "$COUNT" = "0" ]; then
  echo "regression: corpus empty — pass (no contracts to protect yet)."
  exit 0
fi

# Pick a runner. Pytest for Python; npm test for Node. Extend as needed.
if find "$CORPUS" -name '*.py' | grep -q . && command -v pytest >/dev/null 2>&1; then
  echo "runner: pytest"
  pytest "$CORPUS" -q
elif [ -f package.json ] && grep -q '"test"' package.json; then
  echo "runner: npm test ($CORPUS)"
  TEST_MODE="$MODE" npm test -- "$CORPUS"
else
  echo "regression: ERROR — corpus present but no runner detected (pytest / npm test)." >&2
  echo "Wire a runner for tests/regression/ before relying on the guard." >&2
  exit 1
fi
echo "=== regression ($MODE) GREEN ==="
