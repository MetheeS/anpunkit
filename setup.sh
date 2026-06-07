#!/usr/bin/env bash
# setup.sh — anpunkit installer engine (single source of truth for install logic).
#
# Two entry paths share this script:
#   - Developers:  git clone … && bash setup.sh            (--src defaults to ".")
#   - End users:   npx create-anpunkit                      (bin runs: bash setup.sh --src <pkgdir>)
#
# Non-destructive by design. Runs non-interactively under `set -euo pipefail`
# (no TTY assumed). Ownership taxonomy (see README/AGENTS.md):
#   kit-owned   -> refreshed on upgrade (unless user-modified -> *.anpunkit-new)
#   user-owned  -> NEVER overwritten
#   hybrid      -> merged idempotently, never replaced
#
# Flags: --src DIR --kb-path P --kb-remote URL --no-kb --force --dry-run
set -euo pipefail

SRC="."
KB_PATH="${ANPUNKIT_KB_PATH:-}"
KB_REMOTE="${ANPUNKIT_KB_REMOTE:-}"
NO_KB=0
FORCE=0
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --src)       SRC="$2"; shift 2;;
    --kb-path)   KB_PATH="$2"; shift 2;;
    --kb-remote) KB_REMOTE="$2"; shift 2;;
    --no-kb)     NO_KB=1; shift;;
    --force)     FORCE=1; shift;;
    --dry-run)   DRY=1; shift;;
    *) echo "unknown flag: $1" >&2; exit 2;;
  esac
done

DEST="$(pwd)"
say() { printf '%s\n' "$*"; }
act() { if [ "$DRY" = 1 ]; then say "  [dry-run] $*"; else say "  $*"; fi; }

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$1"; fi
}

say "anpunkit setup — dest: $DEST  src: $SRC  $([ "$DRY" = 1 ] && echo '(DRY-RUN)')"

MAN_SRC="$SRC/.claude/anpunkit-manifest.json"
MAN_DEST="$DEST/.claude/anpunkit-manifest.json"
[ -f "$MAN_SRC" ] || { echo "FATAL: missing $MAN_SRC (corrupt kit)"; exit 1; }
NEW_VER=$(python3 -c "import json;print(json.load(open('$MAN_SRC'))['version'])")

# ---- determine mode from installed manifest
MODE="fresh"
if [ -f "$MAN_DEST" ]; then
  OLD_VER=$(python3 -c "import json;print(json.load(open('$MAN_DEST')).get('version',''))" 2>/dev/null || echo "")
  if   [ "$OLD_VER" = "$NEW_VER" ]; then MODE="repair"
  elif [ -z "$OLD_VER" ]; then MODE="upgrade"
  else
    # crude semver compare
    if [ "$(printf '%s\n%s\n' "$OLD_VER" "$NEW_VER" | sort -V | tail -1)" = "$NEW_VER" ] && [ "$OLD_VER" != "$NEW_VER" ]; then MODE="upgrade"; else MODE="newer-installed"; fi
  fi
fi
say "mode: $MODE (installed: ${OLD_VER:-none} -> new: $NEW_VER)"
[ "$MODE" = "newer-installed" ] && say "  ! installed version is newer than this package — proceeding as repair, review carefully."

BACKUP="$DEST/.anpunkit-backup-$(date +%Y%m%d-%H%M%S)"
backup_one() {
  [ "$MODE" = "fresh" ] && return 0
  [ -f "$1" ] || return 0
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$BACKUP/$(dirname "${1#$DEST/}")"
  cp -p "$1" "$BACKUP/${1#$DEST/}"
}

# ---- per kit-owned file: write / refresh / keep-as-new
# Reads kit-owned list from the NEW manifest.
install_kit_file() {
  local rel="$1" s="$SRC/$1" d="$DEST/$1"
  [ -f "$s" ] || return 0
  if [ ! -f "$d" ]; then
    act "write    $rel"; [ "$DRY" = 1 ] && return 0
    mkdir -p "$(dirname "$d")"; cp -p "$s" "$d"; return 0
  fi
  # present — compare against the INSTALLED manifest's recorded checksum
  local recorded; recorded=$(python3 - "$MAN_DEST" "$rel" <<'PY' 2>/dev/null || true
import json,sys
try:
    m=json.load(open(sys.argv[1]))
    print(next((f["sha256"] for f in m["files"] if f["path"]==sys.argv[2]),""))
except Exception: print("")
PY
)
  local cur; cur=$(sha "$d")
  if [ "$cur" = "$recorded" ] || [ -z "$recorded" ] && [ "$SRC" = "." ]; then
    # unmodified since last install (or clone flow with file already in place) -> refresh
    if [ "$cur" = "$(sha "$s")" ]; then act "ok       $rel (identical)"; else
      backup_one "$d"; act "refresh  $rel"; [ "$DRY" = 1 ] || cp -p "$s" "$d"; fi
  else
    # user-modified kit file
    if [ "$FORCE" = 1 ]; then backup_one "$d"; act "force    $rel (overwritten)"; [ "$DRY" = 1 ] || cp -p "$s" "$d"
    else act "keep     $rel (user-modified) -> wrote $rel.anpunkit-new"; [ "$DRY" = 1 ] || cp -p "$s" "$d.anpunkit-new"; fi
  fi
}

say ""; say "[1/6] kit-owned files (taxonomy):"
if [ "$SRC" != "." ]; then
  while IFS= read -r rel; do install_kit_file "$rel"; done < <(python3 -c "import json;[print(f['path']) for f in json.load(open('$MAN_SRC'))['files']]")
else
  say "  clone flow (src=.) — kit files already in place; verifying + generating only."
fi

# ---- generate command adapters from commands.src/ (manifest-owned output)
say ""; say "[2/6] generate command adapters:"
gen_adapters() {
  mkdir -p "$DEST/.claude/commands" "$DEST/.cursor/commands" "$DEST/.cursor/rules"
  for f in "$DEST"/commands.src/*.md; do
    [ -f "$f" ] || continue
    n=$(basename "$f")
    act "claude   .claude/commands/$n"
    act "cursor   .cursor/commands/$n"
    [ "$DRY" = 1 ] && continue
    cp -p "$f" "$DEST/.claude/commands/$n"
    awk 'BEGIN{fm=0} NR==1 && $0=="---"{fm=1; next} fm==1 && $0=="---"{fm=0; next} fm==0{print}' "$f" \
      | sed '/^$/{1d}' > "$DEST/.cursor/commands/$n"
  done
}
gen_adapters

# ---- hybrid JSON merge: ensure the 3 hook entries, never drop user keys
say ""; say "[3/6] wire hooks (idempotent merge):"
merge_settings() {
  [ "$DRY" = 1 ] && { act "merge    .claude/settings.json + .cursor/hooks.json"; return 0; }
  backup_one "$DEST/.claude/settings.json"; backup_one "$DEST/.cursor/hooks.json"
  python3 - "$DEST" <<'PY'
import json,os,sys
dest=sys.argv[1]
def load(p,default):
    try: return json.load(open(p))
    except Exception: return default
# Claude settings.json
sp=os.path.join(dest,".claude/settings.json")
s=load(sp,{})
s.setdefault("$schema","https://json.schemastore.org/claude-code-settings.json")
hooks=s.setdefault("hooks",{})
def ensure(event,matcher,cmd):
    arr=hooks.setdefault(event,[])
    for blk in arr:
        for h in blk.get("hooks",[]):
            if h.get("command")==cmd: return
    blk={"hooks":[{"type":"command","command":cmd}]}
    if matcher: blk={"matcher":matcher,**blk}
    arr.append(blk)
ensure("SessionStart","startup|clear|compact","bash .claude/hooks/session-start.sh")
ensure("PreCompact","auto|manual","bash .claude/hooks/pre-compact.sh")
ensure("SubagentStop","","bash .claude/hooks/subagent-stop.sh")
os.makedirs(os.path.dirname(sp),exist_ok=True)
json.dump(s,open(sp,"w"),indent=2); open(sp,"a").write("\n")
# Cursor hooks.json
cp=os.path.join(dest,".cursor/hooks.json")
c=load(cp,{"version":1,"hooks":{}})
ch=c.setdefault("hooks",{})
def cursor_ensure(event,cmd):
    arr=ch.setdefault(event,[])
    if not any(h.get("command")==cmd for h in arr): arr.append({"command":cmd})
cursor_ensure("sessionStart","bash .claude/hooks/cursor-session-start.sh")
cursor_ensure("preCompact","bash .claude/hooks/pre-compact.sh")
cursor_ensure("subagentStop","bash .claude/hooks/subagent-stop.sh")
os.makedirs(os.path.dirname(cp),exist_ok=True)
json.dump(c,open(cp,"w"),indent=2); open(cp,"a").write("\n")
print("  merged .claude/settings.json + .cursor/hooks.json")
PY
}
merge_settings

# ---- AGENTS.md / CLAUDE.md non-clobber + VERIFY (bare import + on-disk + SENTINEL)
say ""; say "[4/6] AGENTS.md / CLAUDE.md verify:"
# non-clobber: if a *pre-existing user* file differs from kit and we're fresh, keep user copy as-is and stage kit as *.anpunkit.md
# (in clone/scaffold flow the kit files are the ones on disk; this guards a user who already had their own)
verify_import() {
  local CL="$DEST/CLAUDE.md" AG="$DEST/AGENTS.md"
  [ -f "$AG" ] || { echo "FATAL VERIFY: AGENTS.md not on disk"; exit 1; }
  # bare top-level @AGENTS.md import (not indented, not fenced)
  if ! grep -qE '^@AGENTS\.md[[:space:]]*$' "$CL"; then
    echo "FATAL VERIFY: CLAUDE.md is missing a bare top-level '@AGENTS.md' import line"; exit 1; fi
  # sentinel present in AGENTS.md
  if ! grep -q 'ANPUNKIT-AGENTS-SENTINEL' "$AG"; then
    echo "FATAL VERIFY: AGENTS.md sentinel missing (file clobbered or empty?)"; exit 1; fi
  say "  VERIFY ok: bare @AGENTS.md import + AGENTS.md on disk + sentinel present."
}
verify_import

# ---- .gitignore: patch, not replace
say ""; say "[5/6] .gitignore patch:"
patch_gitignore() {
  local gi="$DEST/.gitignore"
  local -a needles=("docs/.snapshots/" "docs/.kb-snapshot.md" ".anpunkit-backup-*/" "*.anpunkit-new")
  [ "$DRY" = 1 ] && { act "patch .gitignore (${#needles[@]} entries)"; return 0; }
  touch "$gi"
  for n in "${needles[@]}"; do grep -qxF "$n" "$gi" || printf '%s\n' "$n" >> "$gi"; done
  say "  patched .gitignore (idempotent)."
}
patch_gitignore

# ---- KB config (optional)
say ""; say "[6/6] shared KB:"
configure_kb() {
  local cfg="$DEST/.claude/kb-config.json"
  if [ "$NO_KB" = 1 ]; then say "  --no-kb: skipping KB."; return 0; fi
  if [ -z "$KB_PATH" ] && [ -z "$KB_REMOTE" ]; then
    if [ -t 0 ]; then
      printf "  Local path to cloned anpunkit-kb repo (blank to skip): "; read -r KB_PATH || true
      [ -z "$KB_PATH" ] && { say "  skipped KB (no path given)."; return 0; }
    else
      say "  no KB flags + no TTY -> skipping KB (re-run with --kb-path / --kb-remote)."; return 0
    fi
  fi
  if [ -n "$KB_PATH" ] && [ ! -d "$KB_PATH" ]; then
    echo "  ! KB path '$KB_PATH' not a directory. Clone your anpunkit-kb repo first."; return 0; fi
  if [ -n "$KB_REMOTE" ]; then
    git ls-remote "$KB_REMOTE" >/dev/null 2>&1 || say "  ! warning: cannot reach KB remote '$KB_REMOTE' (configuring anyway)."; fi
  [ "$DRY" = 1 ] && { act "write .claude/kb-config.json"; return 0; }
  mkdir -p "$DEST/.claude"
  python3 -c "import json;json.dump({'path':'$KB_PATH','remote':'$KB_REMOTE'},open('$cfg','w'),indent=2)"
  say "  wrote .claude/kb-config.json"
}
configure_kb

# ---- finalize: stamp the installed manifest (copy the new one)
if [ "$DRY" != 1 ]; then
  cp -p "$MAN_SRC" "$MAN_DEST" 2>/dev/null || true
  [ -d "$BACKUP" ] && say "" && say "backup written: ${BACKUP#$DEST/}"
fi

say ""; say "anpunkit setup complete ($MODE). Open Claude Code or Cursor — the SessionStart/sessionStart hook fires automatically."
if [ "$DRY" = 1 ]; then say "(dry-run: no files were written.)"; fi
exit 0
