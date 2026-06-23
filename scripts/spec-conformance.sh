#!/usr/bin/env bash
# spec-conformance.sh — block GREEN until the phase spec is fully filled and every
# case is verified by a boundary test (v2.2). Runs between RED and GREEN, replacing
# the v2.1 human TEST REVIEW gate. (§5.55, rule 18)
#
# Two checks, both loud-fail (nonzero), no side effects:
#   1. NO `TBD` remains in docs/spec-phase-<n>.md or any fixture it references.
#   2. EVERY case-id in the spec table is cited by a test via `# spec: <case-id>`
#      (or `// spec: <case-id>`) under tests/ or e2e/.
#
#   bash scripts/spec-conformance.sh <phase-n>
#
# The case→test citation here, plus the placement convention (contract/transition
# tests live in tests/regression/), is what closes the rule-14 chain: reachable
# transition → filled case (rule 14) → cited boundary test (this) → regression corpus.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

N="${1:-}"
[ -n "$N" ] || { echo "spec-conformance: usage: spec-conformance.sh <phase-n>" >&2; exit 2; }

SPEC="docs/spec-phase-${N}.md"
[ -f "$SPEC" ] || { echo "spec-conformance: $SPEC not found." >&2; exit 2; }

FAIL=0

# ---- 1. no TBD left in the spec ----
if grep -nE '\bTBD\b' "$SPEC" >/dev/null 2>&1; then
  echo "spec-conformance: FAIL — unfilled 'TBD' marker(s) remain in $SPEC:" >&2
  grep -nE '\bTBD\b' "$SPEC" | sed 's/^/    /' >&2
  echo "  Every case must be filled (or escalated as CASE-SET-DIVERGENCE) before GREEN." >&2
  FAIL=1
fi

# ---- referenced fixtures: must exist + carry no TBD ----
FIXREFS="$(grep -oE 'fixtures/[A-Za-z0-9_./-]+\.json' "$SPEC" | sort -u || true)"
if [ -n "$FIXREFS" ]; then
  while IFS= read -r fx; do
    [ -n "$fx" ] || continue
    if [ ! -f "$fx" ]; then
      echo "spec-conformance: FAIL — referenced fixture missing: $fx" >&2
      FAIL=1
    elif grep -nE '\bTBD\b' "$fx" >/dev/null 2>&1; then
      echo "spec-conformance: FAIL — 'TBD' marker in fixture: $fx" >&2
      FAIL=1
    fi
  done <<EOF
$FIXREFS
EOF
fi

# ---- 2. every case-id cited by a boundary test ----
# case-ids = the FIRST table-column cell of each row, matching PH<n>-... exactly.
# (Parse the column, not a free grep — else `fixtures/PH1-ORDER-01-input.json`
#  would yield a bogus `PH1-ORDER-01-input` case-id.)
CASE_IDS="$(grep -E '^\|' "$SPEC" \
  | awk -F'|' '{ id=$2; gsub(/^[ \t]+|[ \t]+$/,"",id); print id }' \
  | grep -E "^PH${N}-[A-Za-z0-9_-]+$" | sort -u || true)"
if [ -z "$CASE_IDS" ]; then
  echo "spec-conformance: WARN — no PH${N}-* case-ids found in $SPEC (empty spec?)." >&2
fi

SEARCH_DIRS=""
[ -d tests ] && SEARCH_DIRS="$SEARCH_DIRS tests"
[ -d e2e ]   && SEARCH_DIRS="$SEARCH_DIRS e2e"

if [ -n "$CASE_IDS" ]; then
  if [ -z "$SEARCH_DIRS" ]; then
    echo "spec-conformance: FAIL — case-ids exist but no tests/ or e2e/ dir to cite them." >&2
    FAIL=1
  else
    while IFS= read -r cid; do
      [ -n "$cid" ] || continue
      # cite convention: `spec: <case-id>` with a non-id char (or EOL) after, so
      # PH2-ORDER-01 does not match PH2-ORDER-011.
      if grep -rEq -- "spec:[[:space:]]*${cid}([^0-9A-Za-z_-]|$)" $SEARCH_DIRS 2>/dev/null; then
        :
      else
        echo "spec-conformance: FAIL — case ${cid} has no boundary test citing it (# spec: ${cid})." >&2
        FAIL=1
      fi
    done <<EOF
$CASE_IDS
EOF
  fi
fi

if [ "$FAIL" -ne 0 ]; then
  echo "spec-conformance: BLOCKED — fix the above before GREEN." >&2
  exit 1
fi
echo "spec-conformance: OK — phase ${N} spec fully filled; every case-id cited by a boundary test."
exit 0
