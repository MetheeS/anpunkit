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
  -cf - . | tar -C "$TPL" -xf -
echo "built template/ from $ROOT"
find "$TPL" -maxdepth 1 -mindepth 1 | sed 's/^/  /'
