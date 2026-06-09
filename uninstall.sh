#!/usr/bin/env bash
# cpath uninstall script.
# Removes the tagged source-line from ~/.bashrc and ~/.zshrc (with backup),
# then deletes ~/.local/share/cpath.

set -euo pipefail

REPO_URL="https://github.com/max-nothacker/cpath"
INSTALL_DIR="$HOME/.local/share/cpath"
TAG="# cpath ($REPO_URL)"

removed_any=false

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  if ! grep -qF "$TAG" "$rc"; then
    continue
  fi
  echo "Removing cpath source-line from $rc (backup: $rc.cpath-bak)"
  cp "$rc" "$rc.cpath-bak"
  # awk deletes the tag line and the next line (the source-line). Literal
  # string compare avoids escaping the URL slashes in $TAG.
  awk -v tag="$TAG" '
    BEGIN { skip = 0 }
    {
      if (skip > 0) { skip--; next }
      if ($0 == tag) { skip = 1; next }
      print
    }
  ' "$rc.cpath-bak" > "$rc"
  removed_any=true
done

if [ -d "$INSTALL_DIR" ]; then
  echo "Removing $INSTALL_DIR"
  rm -rf "$INSTALL_DIR"
  removed_any=true
fi

if $removed_any; then
  echo
  echo "OK — cpath uninstalled. Reload current shell:  source ~/.bashrc"
else
  echo "Nothing to remove — cpath wasn't installed."
fi
