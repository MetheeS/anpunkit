#!/usr/bin/env bash
# build.sh — assemble the publishable create-anpunkit package by copying the
# kit tree (repo root) into template/. Run before `npm publish`.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
TPL="$HERE/template"
rm -rf "$TPL"; mkdir -p "$TPL"
# Copy everything except the packaging dir, VCS, backups, and build artifacts.
tar -C "$ROOT" \
  --exclude='./create-anpunkit' \
  --exclude='./.git' \
  --exclude='./.github' \
  --exclude='./.anpunkit-backup-*' \
  --exclude='*.anpunkit-new' \
  --exclude='./node_modules' \
  --exclude='./index.html' \
  --exclude='./anpunkit.png' \
  -cf - . | tar -C "$TPL" -xf -
echo "built template/ from $ROOT"

# Regenerate the manifest sha256 values from the actual template tree (v2.1).
# Keeps the version field, refreshes every recorded hash so upgrade detection
# never misclassifies an unmodified file. Anti-drift: hashes are generated, not
# hand-maintained.
MAN="$TPL/.claude/anpunkit-manifest.json"
if [ -f "$MAN" ]; then
  node - "$TPL" "$MAN" <<'NODE'
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const tpl=process.argv[2], manPath=process.argv[3];
const man=JSON.parse(fs.readFileSync(manPath,'utf8'));
for(const f of (man.files||[])){
  const p=path.join(tpl,f.path);
  if(fs.existsSync(p)) f.sha256=crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
}
fs.writeFileSync(manPath,JSON.stringify(man,null,2)+"\n");
console.log('  regenerated manifest checksums ('+(man.files||[]).length+' files), version '+man.version);
NODE
fi

find "$TPL" -maxdepth 1 -mindepth 1 | sed 's/^/  /'
