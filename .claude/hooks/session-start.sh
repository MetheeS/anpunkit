#!/usr/bin/env bash
# SessionStart hook. stdout is injected into Claude's context every session.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

emit () { printf '%s\n' "$1"; }

emit "=== ANPUNKIT AUTO-CONTEXT (injected by hook, NOT optional) ==="
emit ""

# 1. git state
emit "## Git"
emit "branch: $(git branch --show-current 2>/dev/null || echo n/a)"
emit "uncommitted: $(git status --short 2>/dev/null | wc -l | tr -d ' ') file(s)"
git log --oneline -3 2>/dev/null | sed 's/^/  /' || true
emit ""

# 2. active state
if [ -f docs/STATE.md ]; then
  emit "## STATE.md (current position - READ THIS FIRST)"
  cat docs/STATE.md
  emit ""
else
  emit "## STATE.md missing -> run /overview to bootstrap the project."
  emit ""
fi

# 3. issue log
if [ -f docs/ISSUES.md ]; then
  OPEN=$(grep -c '^- \[ \]' docs/ISSUES.md 2>/dev/null || true)
  OPEN=${OPEN:-0}
  emit "## ISSUES.md (${OPEN} open) - check this before debugging anything"
  awk '/^### / {p=1} p' docs/ISSUES.md 2>/dev/null | head -100
  emit ""
fi

# 3b. research index
if [ -f docs/research/INDEX.md ]; then
  RCOUNT=$(grep -c '^[0-9]' docs/research/INDEX.md 2>/dev/null || true)
  RCOUNT=${RCOUNT:-0}
  emit "## research/INDEX.md (${RCOUNT} prior investigations)"
  emit "grep this before any new research or debugging."
  grep '^[0-9]' docs/research/INDEX.md 2>/dev/null | tail -15 | sed 's/^/  /' || true
  emit ""
fi

# 3c. infra status + auth nudge
if [ -f docs/INFRA.md ]; then
  INFRA_STATUS=$(grep -m1 '^phase 0:' docs/INFRA.md 2>/dev/null || true)
  PROJECT_HASH=$(echo "$PWD" | md5sum 2>/dev/null | cut -c1-8 || echo "anpunkit")
  MARKER="/tmp/anpunkit-auth-${USER:-unknown}-${PROJECT_HASH}"
  if [ ! -f "$MARKER" ]; then
    emit "## Azure infra present — auth check needed"
    emit "Run scripts/auth-setup.sh once this session before any Azure work."
    if echo "$INFRA_STATUS" | grep -qi 'NOT DONE'; then
      emit "Phase 0 not complete — run /infra to provision before starting phase 1."
    fi
    emit ""
  fi
fi

# 3d. shared KB — pull latest + load snapshot
KB_CONFIG=".claude/kb-config.json"
if [ -f "$KB_CONFIG" ]; then
  KB_PATH=$(python3 -c "import json; print(json.load(open('$KB_CONFIG')).get('kb_path',''))" 2>/dev/null || echo "")
  KB_PATH_EXPANDED="${KB_PATH/#\~/$HOME}"

  if [ -n "$KB_PATH_EXPANDED" ] && [ -d "$KB_PATH_EXPANDED" ]; then
    emit "## Shared KB"

    # Pull latest (fail silently — offline or no remote shouldn't break session start)
    if git -C "$KB_PATH_EXPANDED" pull --ff-only --quiet 2>/dev/null; then
      emit "KB pulled: OK"
    else
      emit "KB pull skipped (offline or conflict — using local copy)"
    fi

    # Load INDEX.md into session snapshot
    KB_INDEX="${KB_PATH_EXPANDED}/INDEX.md"
    SNAPSHOT="docs/.kb-snapshot.md"

    if [ -f "$KB_INDEX" ]; then
      TODAY=$(date +%Y-%m-%d)
      CUTOFF=$(date -d "6 months ago" +%Y-%m-%d 2>/dev/null \
               || python3 -c "from datetime import date, timedelta; print((date.today() - timedelta(days=180)).isoformat())" 2>/dev/null \
               || echo "2000-01-01")

      {
        echo "# KB snapshot — loaded $(date +%Y-%m-%d)"
        echo "# Stale = created date older than ${CUTOFF}"
        echo ""
        while IFS='|' read -r entry_date domain slug summary rest; do
          entry_date=$(echo "$entry_date" | tr -d ' ')
          # Mark stale if date field present and older than cutoff
          if [ -n "$entry_date" ] && [[ "$entry_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            if [[ "$entry_date" < "$CUTOFF" ]]; then
              echo "[STALE] ${entry_date} |${domain} |${slug} |${summary} |${rest}"
            else
              echo "${entry_date} |${domain} |${slug} |${summary} |${rest}"
            fi
          else
            echo "${entry_date} |${domain} |${slug} |${summary} |${rest}"
          fi
        done < <(grep -v '^#' "$KB_INDEX" | grep -v '^$')
      } > "$SNAPSHOT"

      TOTAL=$(grep -c '|' "$SNAPSHOT" 2>/dev/null || echo 0)
      STALE=$(grep -c '^\[STALE\]' "$SNAPSHOT" 2>/dev/null || echo 0)
      emit "KB snapshot loaded: ${TOTAL} entries (${STALE} stale — researcher will re-research these)"
      emit "Snapshot at docs/.kb-snapshot.md — researcher reads this before web search."
    else
      emit "KB INDEX.md not found at ${KB_PATH_EXPANDED} — run /store-wisdom to populate it."
    fi
    emit ""
  else
    emit "## Shared KB: configured but path not found (${KB_PATH})"
    emit "Re-run setup.sh to fix the KB path."
    emit ""
  fi
fi

# 4. hard rule reminder
emit "## RULES (enforced this session)"
emit "- caveman ULTRA mode is active."
emit "- before debugging ANY error: grep ISSUES.md AND research/INDEX.md first."
emit "- debug attempts: WARN at 2; first hard-stop at 3 STOPS and asks you."
emit "- end of every phase: run /synthesize, then /clear."
emit "- small obvious change? use /quick, not /phase."
emit "- Azure project? run scripts/auth-setup.sh once per session before Azure work."
if [ -f "$KB_CONFIG" ]; then
  emit "- KB active: researcher checks docs/.kb-snapshot.md before web search."
  emit "- learned something worth keeping? run /store-wisdom."
fi
emit "=== END AUTO-CONTEXT ==="
exit 0
