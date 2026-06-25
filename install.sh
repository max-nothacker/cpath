#!/usr/bin/env bash
# cpath install/update script.
# Idempotent — re-run anytime to update; nothing in ~/.bashrc gets duplicated.

set -euo pipefail

REPO_URL="https://github.com/max-nothacker/cpath"
REPO_RAW="https://raw.githubusercontent.com/max-nothacker/cpath/main"
INSTALL_DIR="$HOME/.local/share/cpath"
TAG="# cpath ($REPO_URL)"
SOURCE_LINE='[ -f "$HOME/.local/share/cpath/cpath.sh" ] && . "$HOME/.local/share/cpath/cpath.sh"'

mkdir -p "$INSTALL_DIR"
# Clean up the atomic-write temp file on any exit path.
trap 'rm -f "$INSTALL_DIR/cpath.sh.tmp"' EXIT

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

# Patch every shell rc that exists. Bash is the primary target on WSL but
# detecting zsh users for free is cheap and saves them a manual step.
patched_any=false
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue

  # One-time migration: strip a legacy embedded cpath() block (and the header
  # comment directly above it) left by old installs that appended the function
  # to the rc directly. Detection and removal both key off the `cpath() {` line,
  # so they can never disagree — keying removal off a header comment could
  # mismatch, falsely report a migration, and never actually remove the block.
  if grep -q '^cpath() {' "$rc"; then
    echo "Migrating: removing old embedded cpath() block from $rc (backup: $rc.cpath-bak)"
    cp "$rc" "$rc.cpath-bak"
    awk '
      function flush(   i) { for (i = 0; i < n; i++) print buf[i]; n = 0 }
      drop            { if ($0 ~ /^}$/) drop = 0; next }   # in old body: skip to closing brace
      /^cpath\(\) \{/ { n = 0; drop = 1; next }            # function head: drop buffered header comments
      /^#/            { buf[n++] = $0; next }               # buffer comments (may be the header)
                      { flush(); print }                   # other line: emit buffered comments, then it
      END             { flush() }
    ' "$rc.cpath-bak" > "$rc"
  fi

  # Idempotent rc patch: add the tagged source-line only if it's not already there.
  if ! grep -qF "$TAG" "$rc"; then
    {
      printf '\n%s\n' "$TAG"
      printf '%s\n' "$SOURCE_LINE"
    } >> "$rc"
    echo "Added cpath source-line to $rc"
    patched_any=true
  else
    echo "Source-line already present in $rc (skipped)"
  fi
done

if ! $patched_any && [ ! -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ]; then
  echo "Note: no ~/.bashrc or ~/.zshrc found — add this line to your shell rc manually:"
  echo "  $TAG"
  echo "  $SOURCE_LINE"
fi

echo
echo "OK — cpath ready at $INSTALL_DIR/cpath.sh"
echo "Reload current shell:  source ~/.bashrc   (or ~/.zshrc)"
echo "Or open a new terminal."
