#!/usr/bin/env bash
# spec-staleness.sh — guard the per-phase spec header against upstream drift (v2.2).
#
# The behavioral contract docs/spec-phase-<n>.md carries a GENERATED header that
# transcludes the phase's PLAN.md `- acceptance:` line + the in-scope DATAFLOW.md
# transition rows, plus an embedded hash. If PLAN.md / DATAFLOW.md change after the
# skeleton was stamped (e.g. via /replan), the stored hash no longer matches the
# upstream → the spec must be regenerated/re-filled before SPEC REVIEW. (§5.55, rule 17)
#
# Hashing lives ONLY here (no duplication in agent prompts):
#   bash scripts/spec-staleness.sh stamp <n>    # compute + embed the hash (at /overview, on regenerate)
#   bash scripts/spec-staleness.sh check <n>    # default: recompute + compare; nonzero on drift
#   bash scripts/spec-staleness.sh <n>          # alias for: check <n>
#
# set -euo pipefail; nonzero = loud fail; `stamp` is the only side effect.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

# ---- args ----
SUB="check"
case "${1:-}" in
  stamp) SUB="stamp"; shift;;
  check) SUB="check"; shift;;
esac
N="${1:-}"
[ -n "$N" ] || { echo "spec-staleness: usage: spec-staleness.sh [stamp|check] <phase-n>" >&2; exit 2; }

SPEC="docs/spec-phase-${N}.md"
PLAN="docs/PLAN.md"
DATAFLOW="docs/DATAFLOW.md"
[ -f "$SPEC" ] || { echo "spec-staleness: $SPEC not found." >&2; exit 2; }
[ -f "$PLAN" ] || { echo "spec-staleness: $PLAN not found." >&2; exit 2; }

# ---- sha256 of stdin (portable: sha256sum -> shasum -> node) ----
sha_stdin() {
  if   command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  elif command -v shasum    >/dev/null 2>&1; then shasum -a 256 | cut -d' ' -f1
  else node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>console.log(require('crypto').createHash('sha256').update(d).digest('hex')))"
  fi
}

# normalize: NFC-ish arrow unify (→ -> ->), collapse spaces, trim. Content-sensitive,
# whitespace-insensitive — so cosmetic reflow does not trip the guard, content does.
norm() { sed -e 's/→/->/g' -e 's/[[:space:]]\{1,\}/ /g' -e 's/^ //' -e 's/ $//'; }

# ---- extract this phase's block from PLAN.md (## Phase <n>: ... up to next ## Phase) ----
phase_block() {
  awk -v n="$N" '
    $0 ~ ("^## Phase " n ":") {inblk=1; print; next}
    inblk && /^## Phase /      {inblk=0}
    inblk                      {print}
  ' "$PLAN"
}

BLOCK="$(phase_block || true)"
[ -n "$BLOCK" ] || { echo "spec-staleness: no '## Phase ${N}:' block in $PLAN." >&2; exit 2; }

# acceptance line(s) + dataflow line, normalized
ACC_LINE="$(printf '%s\n' "$BLOCK"   | grep -E '^- acceptance:' | norm || true)"
DF_LINE="$(printf '%s\n'  "$BLOCK"   | grep -E '^- dataflow:'   | norm || true)"

# in-scope transition tokens (from->to) named on the dataflow line
TOKENS="$(printf '%s\n' "$DF_LINE" | norm | grep -oE '[A-Za-z0-9_]+->[A-Za-z0-9_]+' | sort -u || true)"

# matching DATAFLOW.md data-rows (table rows naming an in-scope transition)
DF_ROWS=""
if [ -n "$TOKENS" ] && [ -f "$DATAFLOW" ]; then
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    rows="$(grep -E '^\|' "$DATAFLOW" | norm | grep -F "$tok" || true)"
    DF_ROWS="${DF_ROWS}${rows}
"
  done <<EOF
$TOKENS
EOF
fi
DF_ROWS="$(printf '%s\n' "$DF_ROWS" | grep -v '^$' | sort -u || true)"

# ---- the upstream signature + its hash ----
SIG="$(printf 'ACC:%s\nDF:%s\nROWS:\n%s\n' "$ACC_LINE" "$DF_LINE" "$DF_ROWS")"
WANT="$(printf '%s' "$SIG" | sha_stdin)"

HASH_RE='^<!-- spec-hash: .* -->$'
HAVE="$(grep -E "$HASH_RE" "$SPEC" | head -1 | sed -E 's/^<!-- spec-hash: (.*) -->$/\1/' || true)"

if [ "$SUB" = "stamp" ]; then
  if grep -qE "$HASH_RE" "$SPEC"; then
    tmp="$(mktemp)"
    awk -v h="$WANT" '
      /^<!-- spec-hash: .* -->$/ && !done { print "<!-- spec-hash: " h " -->"; done=1; next }
      { print }
    ' "$SPEC" > "$tmp" && mv "$tmp" "$SPEC"
  else
    echo "spec-staleness: $SPEC has no '<!-- spec-hash: ... -->' header line to stamp." >&2
    exit 2
  fi
  echo "spec-staleness: stamped phase ${N} -> ${WANT}"
  exit 0
fi

# ---- check ----
if [ -z "$HAVE" ] || [ "$HAVE" = "PENDING" ]; then
  echo "spec-staleness: FAIL — phase ${N} spec hash is unstamped (${HAVE:-missing})." >&2
  echo "  Run: bash scripts/spec-staleness.sh stamp ${N}" >&2
  exit 1
fi
if [ "$HAVE" != "$WANT" ]; then
  echo "spec-staleness: FAIL — phase ${N} spec is STALE." >&2
  echo "  Upstream PLAN.md acceptance / DATAFLOW.md rows changed since the skeleton was stamped." >&2
  echo "  stored=${HAVE}  current=${WANT}" >&2
  echo "  Regenerate the skeleton header from current PLAN/DATAFLOW, re-stamp, and re-fill." >&2
  exit 1
fi
echo "spec-staleness: OK — phase ${N} spec header matches upstream (${WANT})."
exit 0
