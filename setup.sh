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
# Claude Code only (v2.3 — Cursor support dropped, §5.69).
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
  else node -e "console.log(require('crypto').createHash('sha256').update(require('fs').readFileSync(process.argv[1])).digest('hex'))" "$1"; fi
}

say "anpunkit setup — dest: $DEST  src: $SRC  $([ "$DRY" = 1 ] && echo '(DRY-RUN)')"

MAN_SRC="$SRC/.claude/anpunkit-manifest.json"
MAN_DEST="$DEST/.claude/anpunkit-manifest.json"
[ -f "$MAN_SRC" ] || { echo "FATAL: missing $MAN_SRC (corrupt kit)"; exit 1; }
NEW_VER=$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).version)" "$MAN_SRC")

# ---- determine mode from installed manifest
MODE="fresh"
if [ -f "$MAN_DEST" ]; then
  OLD_VER=$(node -e "try{console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).version||'')}catch(e){console.log('')}" "$MAN_DEST" 2>/dev/null || echo "")
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
  local recorded; recorded=$(node - "$MAN_DEST" "$rel" <<'NODE' 2>/dev/null || true
const fs=require('fs');
try{
  const m=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
  const f=(m.files||[]).find(f=>f.path===process.argv[3]);
  console.log(f?f.sha256:'');
}catch(e){console.log('');}
NODE
)
  local cur; cur=$(sha "$d")
  local new; new=$(sha "$s")
  # already identical to the new version -> nothing to do (regardless of manifest)
  if [ "$cur" = "$new" ]; then act "ok       $rel (identical)"; return 0; fi
  # NOTE: bash gives || and && EQUAL precedence (left-assoc) — group explicitly.
  if [ "$cur" = "$recorded" ] || { [ -z "$recorded" ] && [ "$SRC" = "." ]; }; then
    # unmodified since last install (or clone flow) -> refresh to the new version
    backup_one "$d"; act "refresh  $rel"; [ "$DRY" = 1 ] || cp -p "$s" "$d"
  else
    # user-modified kit file
    if [ "$FORCE" = 1 ]; then backup_one "$d"; act "force    $rel (overwritten)"; [ "$DRY" = 1 ] || cp -p "$s" "$d"
    else act "keep     $rel (user-modified) -> wrote $rel.anpunkit-new"; [ "$DRY" = 1 ] || cp -p "$s" "$d.anpunkit-new"; fi
  fi
}

say ""; say "[1/6] kit-owned files (taxonomy):"
if [ "$SRC" != "." ]; then
  while IFS= read -r rel; do install_kit_file "$rel"; done < <(node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).files.forEach(f=>console.log(f.path))" "$MAN_SRC")
else
  say "  clone flow (src=.) — kit files already in place; verifying + generating only."
fi

# ---- generate command adapters from commands.src/ (manifest-owned output)
say ""; say "[2/6] generate command adapters (.claude/commands/):"
gen_adapters() {
  mkdir -p "$DEST/.claude/commands"
  for f in "$DEST"/commands.src/*.md; do
    [ -f "$f" ] || continue
    n=$(basename "$f")
    act "claude   .claude/commands/$n"
    [ "$DRY" = 1 ] || cp -p "$f" "$DEST/.claude/commands/$n"
  done
}
gen_adapters

# ---- hybrid JSON merge: ensure the Claude hook entries, never drop user keys
say ""; say "[3/6] wire hooks (idempotent merge, .claude/settings.json):"
merge_settings() {
  [ "$DRY" = 1 ] && { act "merge    .claude/settings.json"; return 0; }
  backup_one "$DEST/.claude/settings.json"
  node - "$DEST" <<'NODE'
const fs=require('fs'),path=require('path');
const dest=process.argv[2];
const load=(p,d)=>{try{return JSON.parse(fs.readFileSync(p,'utf8'))}catch(e){return d}};
const save=(p,o)=>{fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,JSON.stringify(o,null,2)+"\n")};
const sp=path.join(dest,'.claude/settings.json');
const s=load(sp,{});
if(!s.$schema)s.$schema='https://json.schemastore.org/claude-code-settings.json';
s.hooks=s.hooks||{};
const ensure=(event,matcher,cmd)=>{
  const arr=s.hooks[event]=s.hooks[event]||[];
  for(const blk of arr)for(const h of (blk.hooks||[]))if(h.command===cmd)return;
  const blk={hooks:[{type:'command',command:cmd}]};
  if(matcher)blk.matcher=matcher;
  arr.push(blk);
};
ensure('SessionStart','startup|clear|compact','bash .claude/hooks/session-start.sh');
ensure('PreCompact','auto|manual','bash .claude/hooks/pre-compact.sh');
ensure('SubagentStop','','bash .claude/hooks/subagent-stop.sh');
save(sp,s);
console.log('  merged .claude/settings.json');
NODE
}
merge_settings

# ---- AGENTS.md / CLAUDE.md non-clobber + VERIFY (bare import + on-disk + SENTINEL)
say ""; say "[4/6] AGENTS.md / CLAUDE.md verify:"
# non-clobber: if a *pre-existing user* file differs from kit and we're fresh, keep user copy as-is and stage kit as *.anpunkit.md
# (in clone/scaffold flow the kit files are the ones on disk; this guards a user who already had their own)
verify_import() {
  local CL="$DEST/CLAUDE.md" AG="$DEST/AGENTS.md"
  [ -f "$AG" ] || { echo "FATAL VERIFY: AGENTS.md not on disk"; exit 1; }
  if ! grep -q 'ANPUNKIT-AGENTS-SENTINEL' "$AG"; then
    echo "FATAL VERIFY: AGENTS.md sentinel missing (file clobbered or empty?)"; exit 1; fi
  if ! grep -qE '^@AGENTS\.md[[:space:]]*$' "$CL"; then
    echo "FATAL VERIFY: CLAUDE.md is missing a bare top-level '@AGENTS.md' import line"; exit 1; fi
  say "  VERIFY ok: bare @AGENTS.md import + AGENTS.md on disk + sentinel present."
}
verify_import

# ---- .gitignore: patch, not replace
say ""; say "[5/6] .gitignore patch:"
patch_gitignore() {
  local gi="$DEST/.gitignore"
  local -a needles=("docs/.snapshots/" "docs/.kb-snapshot.md" "docs/evidence/" ".anpunkit-backup-*/" "*.anpunkit-new")
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

  # Path-first by design: YOU clone the KB repo (you own the git auth);
  # anpunkit only records where it lives. After that, the session-start hook
  # pulls and /store-wisdom commits+pushes (human-gated) — no manual git needed.
  if [ -z "$KB_PATH" ]; then
    if [ -t 0 ]; then
      printf "  Local path to your cloned anpunkit-kb repo (blank to skip): "
      read -r KB_PATH || true
      [ -z "$KB_PATH" ] && { say "  skipped KB."; return 0; }
    else
      say "  no KB flags + no TTY -> skipping KB (re-run with --kb-path <dir>)."; return 0
    fi
  fi
  if [ ! -d "$KB_PATH" ]; then
    echo "  ! KB path '$KB_PATH' is not a directory. Clone your KB repo first, e.g.:"
    echo "      git clone git@github.com:<you>/anpunkit-kb.git ~/anpunkit-kb"
    echo "    then re-run with --kb-path ~/anpunkit-kb"
    return 0
  fi

  # remote is metadata: explicit --kb-remote wins, else read the clone's origin
  if [ -z "$KB_REMOTE" ] && [ -d "$KB_PATH/.git" ]; then
    KB_REMOTE=$(git -C "$KB_PATH" remote get-url origin 2>/dev/null || echo "")
  fi
  if [ -n "$KB_REMOTE" ]; then
    git ls-remote "$KB_REMOTE" >/dev/null 2>&1 \
      || say "  ! warning: cannot reach KB remote '$KB_REMOTE' right now (recording anyway; pull/push will need it)."
  fi

  [ "$DRY" = 1 ] && { act "write .claude/kb-config.json (path: $KB_PATH)"; return 0; }
  mkdir -p "$DEST/.claude"
  node -e "require('fs').writeFileSync(process.argv[1],JSON.stringify({path:process.argv[2],remote:process.argv[3]},null,2)+'\n')" "$cfg" "$KB_PATH" "$KB_REMOTE"
  say "  wrote .claude/kb-config.json (path: $KB_PATH${KB_REMOTE:+, remote: $KB_REMOTE})"
}

configure_kb

# ---- finalize: stamp the installed manifest (copy the new one)
if [ "$DRY" != 1 ]; then
  cp -p "$MAN_SRC" "$MAN_DEST" 2>/dev/null || true
  [ -d "$BACKUP" ] && say "" && say "backup written: ${BACKUP#$DEST/}"
fi

say ""; say "anpunkit setup complete ($MODE). Open Claude Code — the SessionStart hook fires automatically."
if [ "$DRY" = 1 ]; then say "(dry-run: no files were written.)"; fi
exit 0
