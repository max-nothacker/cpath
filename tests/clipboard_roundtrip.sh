#!/usr/bin/env bash
# Clipboard round-trip test.
#
# When `cpath` is called with no arguments it reads the Windows clipboard,
# prints the converted path, and writes the converted form BACK to the
# clipboard. Successive bare invocations therefore alternate between the
# Windows and WSL forms of the same path — call 1 returns the WSL form,
# call 2 returns the original Windows form, call 3 returns the WSL form
# again, and so on.
#
# This test seeds the clipboard with a known Windows path and asserts that
# three successive `cpath` calls produce the expected alternating output
# (both on stdout and on the clipboard).
#
# Requires:
#   - cpath.sh (autodetected at ../cpath.sh; override via $CPATH_SH)
#   - clip.exe + powershell.exe reachable via WSL interop
#   - script(1) from util-linux (for allocating a pty so cpath's `[ -t 0 ]`
#     stdin check evaluates true under non-interactive invocation)

set -eu

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPATH_SH="${CPATH_SH:-$HERE/../cpath.sh}"
[ -f "$CPATH_SH" ] || { echo "cpath.sh not found at $CPATH_SH" >&2; exit 1; }

# Use a system path that exists everywhere; round-trips cleanly through wslpath.
WIN_PATH='C:\Users\Public\Desktop'
WSL_PATH='/mnt/c/Users/Public/Desktop'

seed_clipboard() {
  printf '%s' "$1" | clip.exe
  sleep 0.15  # small race-buffer for the clipboard write to settle
}

read_clipboard() {
  powershell.exe -NoProfile -Command Get-Clipboard 2>/dev/null \
    | tr -d '\r' | head -n 1
}

# Allocate a pty so the TTY branch fires inside cpath.
# SHELL=/bin/bash so we don't get dash semantics on `[[ ... ]]`.
run_cpath_bare() {
  SHELL=/bin/bash script -qc "source $CPATH_SH && cpath" /dev/null \
    | tr -d '\r' | head -n 1
}

fail=0
check() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    printf '  ok  %s\n' "$label"
  else
    printf '  FAIL %s\n        want: %s\n        got:  %s\n' \
      "$label" "$want" "$got"
    fail=1
  fi
}

echo "== Clipboard round-trip alternation =="
seed_clipboard "$WIN_PATH"

# Call 1: clipboard was Windows form → should convert to WSL form.
out=$(run_cpath_bare); clip=$(read_clipboard)
check "call 1 stdout"    "$out"  "$WSL_PATH"
check "call 1 clipboard" "$clip" "$WSL_PATH"

# Call 2: clipboard now holds WSL form → should convert back to Windows form.
out=$(run_cpath_bare); clip=$(read_clipboard)
check "call 2 stdout"    "$out"  "$WIN_PATH"
check "call 2 clipboard" "$clip" "$WIN_PATH"

# Call 3: clipboard holds Windows form again → WSL form once more.
out=$(run_cpath_bare); clip=$(read_clipboard)
check "call 3 stdout"    "$out"  "$WSL_PATH"
check "call 3 clipboard" "$clip" "$WSL_PATH"

if [ $fail -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL"
  exit 1
fi
