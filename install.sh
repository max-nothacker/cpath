#!/usr/bin/env bash
# cpath install/update script.
# Idempotent — re-run anytime to update; nothing in ~/.bashrc gets duplicated.

set -euo pipefail

REPO_URL="https://github.com/max-nothacker/cpath"
REPO_RAW="https://raw.githubusercontent.com/max-nothacker/cpath/main"
INSTALL_DIR="$HOME/.local/share/cpath"
RC="$HOME/.bashrc"
TAG="# cpath ($REPO_URL)"
SOURCE_LINE='[ -f "$HOME/.local/share/cpath/cpath.sh" ] && . "$HOME/.local/share/cpath/cpath.sh"'

mkdir -p "$INSTALL_DIR"

# Local-clone mode: if this script lives next to a cpath.sh, copy from there.
# Works for `bash ./install.sh` from a clone. Falls back to download for `curl | bash`.
SCRIPT_SRC="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_SRC" ] && [ -f "$SCRIPT_SRC" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
else
  SCRIPT_DIR=""
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/cpath.sh" ]; then
  echo "Installing from local clone: $SCRIPT_DIR/cpath.sh"
  install -m 0644 "$SCRIPT_DIR/cpath.sh" "$INSTALL_DIR/cpath.sh"
else
  echo "Downloading cpath.sh from $REPO_RAW"
  curl -fsSL "$REPO_RAW/cpath.sh" -o "$INSTALL_DIR/cpath.sh.tmp"
  mv "$INSTALL_DIR/cpath.sh.tmp" "$INSTALL_DIR/cpath.sh"
  chmod 0644 "$INSTALL_DIR/cpath.sh"
fi

# One-time migration: strip the embedded cpath block left by the original
# `curl >> ~/.bashrc` install. Keeps a backup at ~/.bashrc.cpath-bak.
if [ -f "$RC" ] && grep -q '^cpath() {' "$RC"; then
  echo "Migrating: removing old embedded cpath block from $RC (backup: $RC.cpath-bak)"
  sed -i.cpath-bak '/^# cpath — convert path$/,/^}$/d' "$RC"
fi

# Idempotent rc patch: add the tagged source-line only if it's not already there.
if [ ! -f "$RC" ] || ! grep -qF "$TAG" "$RC"; then
  {
    printf '\n%s\n' "$TAG"
    printf '%s\n' "$SOURCE_LINE"
  } >> "$RC"
  echo "Added cpath source-line to $RC"
else
  echo "Source-line already present in $RC (skipped)"
fi

echo
echo "OK — cpath ready at $INSTALL_DIR/cpath.sh"
echo "Reload current shell:  source ~/.bashrc"
echo "Or open a new terminal."
