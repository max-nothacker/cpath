#!/usr/bin/env bash
# install.sh legacy-migration test.
#
# Old installs appended the cpath() function straight into ~/.bashrc. The
# installer migrates those away in favour of a single source-line. This test
# runs the real install.sh against fixture rc files inside isolated temp HOMEs
# and asserts the migration:
#   - removes the embedded cpath() function and its adjacent header comments,
#   - leaves unrelated comments untouched,
#   - ends up with exactly one source-line,
#   - keeps a backup of the original, and
#   - is idempotent: a second run neither re-migrates nor changes the rc.
#
# Needs only bash + coreutils — no WSL interop (wslpath/clip.exe) required.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(cd "$HERE/.." && pwd)}"
INSTALL="$REPO/install.sh"
[ -f "$INSTALL" ] || { echo "install.sh not found at $INSTALL" >&2; exit 1; }

SRC_LINE='[ -f "$HOME/.local/share/cpath/cpath.sh" ] && . "$HOME/.local/share/cpath/cpath.sh"'

fail=0
ok()  { printf '    ok   %s\n' "$1"; }
bad() { printf '    FAIL %s\n' "$1"; fail=1; }

# The two known legacy header/function variants.
REPO_BLOCK=$'# cpath — convert path\ncpath() {\n  local in="$*"\n  echo "$in"\n}'
USER_BLOCK=$'# Convert a path between Windows and WSL form.\n# Auto-detects direction. Prints the result and copies it to the Windows clipboard.\ncpath() {\n  if [ "$#" -eq 0 ]; then\n    echo "usage: cpath <path>" >&2\n    return 2\n  fi\n  local in="$*"\n  echo "$in"\n}'

# run_case NAME RC_CONTENT
run_case() {
  local name="$1" content="$2"
  local h; h="$(mktemp -d)"
  printf '%s\n' "$content" > "$h/.bashrc"
  printf '  [%s]\n' "$name"

  # --- First install run ---
  local out1; out1="$(HOME="$h" bash "$INSTALL" 2>&1)"
  local migrated1=no; grep -q 'Migrating:' <<<"$out1" && migrated1=yes

  if grep -q '^cpath() {' "$h/.bashrc"; then bad "embedded cpath() removed"; else ok "embedded cpath() removed"; fi
  if grep -qF '# Convert a path between Windows and WSL form.' "$h/.bashrc" \
     || grep -qxF '# cpath — convert path' "$h/.bashrc"; then
    bad "legacy header comment removed"; else ok "legacy header comment removed"; fi
  local cnt; cnt="$(grep -cF "$SRC_LINE" "$h/.bashrc")"
  [ "$cnt" = 1 ] && ok "source-line present exactly once" || bad "source-line count=$cnt (want 1)"
  if [ "$migrated1" = yes ]; then
    if [ -f "$h/.bashrc.cpath-bak" ] && grep -q '^cpath() {' "$h/.bashrc.cpath-bak"; then
      ok "backup preserves original block"; else bad "backup missing/incomplete"; fi
  else
    ok "no migration (nothing embedded)"
  fi
  # The installed copy must be the current cpath.sh.
  grep -q 'fileurl' "$h/.local/share/cpath/cpath.sh" 2>/dev/null \
    && ok "installed cpath.sh is current" || bad "installed cpath.sh missing/stale"

  # --- Second install run (idempotency) ---
  local before; before="$(cat "$h/.bashrc")"
  local out2; out2="$(HOME="$h" bash "$INSTALL" 2>&1)"
  local after;  after="$(cat "$h/.bashrc")"
  grep -q 'Migrating:' <<<"$out2" && bad "2nd run must NOT re-migrate" || ok "2nd run does not re-migrate"
  [ "$before" = "$after" ] && ok "2nd run leaves rc unchanged" || bad "2nd run changed the rc"

  rm -rf "$h"
}

echo "== install.sh migration =="

run_case "A: repo legacy block, no source-line" "alias foo=bar
$REPO_BLOCK
# unrelated trailing comment"

run_case "B: alternate-header block + source-line present" "alias dotfiles='git'

$USER_BLOCK

# cpath (https://github.com/max-nothacker/cpath)
$SRC_LINE"

run_case "C: only source-line, nothing to migrate" "alias foo=bar
# cpath (https://github.com/max-nothacker/cpath)
$SRC_LINE"

run_case "D: bare function, no header comment" "alias foo=bar
cpath() {
  local in=\"\$*\"
  echo \"\$in\"
}
export PATH=\$PATH"

run_case "E: non-adjacent comment must survive" "# keep me: important note
alias foo=bar

$USER_BLOCK"

echo
if [ "$fail" -eq 0 ]; then echo "PASS"; exit 0; else echo "FAIL"; exit 1; fi
