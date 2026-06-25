#!/usr/bin/env bash
# Conversion test (stdout-only).
#
# Sources cpath.sh and asserts that the default graph and the explicit target
# flags (-i/-s/-f) produce the expected output on stdout. cpath also writes the
# result to the Windows clipboard as a side effect; this test ignores that and
# only checks the first line of stdout.
#
# Requires:
#   - cpath.sh (autodetected at ../cpath.sh; override via $CPATH_SH)
#   - wslpath + clip.exe reachable via WSL interop

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPATH_SH="${CPATH_SH:-$HERE/../cpath.sh}"
[ -f "$CPATH_SH" ] || { echo "cpath.sh not found at $CPATH_SH" >&2; exit 1; }
# shellcheck disable=SC1090
. "$CPATH_SH"

# Distro-dependent UNC host, so wsl<->win round-trips match this machine.
DISTRO="${WSL_DISTRO_NAME:-Ubuntu}"
UNC_HOME="\\\\wsl.localhost\\$DISTRO\\home\\user\\notes"
URL_HOME="file://wsl.localhost/$DISTRO/home/user/notes"

fail=0
check() { # label  got  want
  if [ "$2" = "$3" ]; then
    printf '  ok  %s\n' "$1"
  else
    printf '  FAIL %s\n        want: %s\n        got:  %s\n' "$1" "$3" "$2"
    fail=1
  fi
}
# Capture only stdout's first line (drop the clipboard side effect / any CR).
run() { cpath "$@" 2>/dev/null | head -n 1 | tr -d '\r'; }

echo "== Default graph =="
check "file:// -> Windows" \
  "$(run 'file:///C:/Users/maxno/OneDrive%20-%20PennO365/B1-Classes/HW7-1.pdf')" \
  'C:\Users\maxno\OneDrive - PennO365\B1-Classes\HW7-1.pdf'
check "Windows -> WSL" "$(run 'C:\Users\Public\Desktop')" '/mnt/c/Users/Public/Desktop'
check "WSL -> Windows" "$(run /mnt/c/Users/Public/Desktop)" 'C:\Users\Public\Desktop'

echo "== Explicit -i / --windows (to Windows) =="
check "-i on file://" "$(run -i 'file:///C:/a%20b/x.pdf')" 'C:\a b\x.pdf'
check "-i on WSL"     "$(run -i /mnt/c/Users/Public)"      'C:\Users\Public'
check "--windows on file://" "$(run --windows 'file:///C:/x.pdf')" 'C:\x.pdf'

echo "== Explicit -s / --wsl (to WSL) =="
check "-s on file://" "$(run -s 'file:///C:/a%20b/x.pdf')" '/mnt/c/a b/x.pdf'
check "-s on Windows" "$(run -s 'C:\Users\Public')"        '/mnt/c/Users/Public'

echo "== Explicit -f / --fileurl (to file://) =="
check "-f on Windows drive (spaces)" \
  "$(run -f 'C:\Users\maxno\OneDrive - PennO365\HW7-1.pdf')" \
  'file:///C:/Users/maxno/OneDrive%20-%20PennO365/HW7-1.pdf'
check "-f on WSL (UNC host)" "$(run -f /home/user/notes)" "$URL_HOME"
check "-f round-trips a file:// URL" \
  "$(run -f 'file:///C:/a%20b/x.pdf')" 'file:///C:/a%20b/x.pdf'

echo "== Spaces survive \$* joining (unquoted forward-slash & WSL) =="
check "forward-slash Windows w/ spaces -> WSL" \
  "$(run C:/Users/maxno/some file with spaces.md)" \
  '/mnt/c/Users/maxno/some file with spaces.md'
check "WSL path w/ spaces -> file://" \
  "$(run -f /mnt/c/Users/maxno/some file with spaces.md)" \
  'file:///C:/Users/maxno/some%20file%20with%20spaces.md'

echo "== Errors =="
# Call cpath directly (not via run()): a pipe would mask its exit code.
cpath -x /tmp >/dev/null 2>&1; check "unknown flag exits 2" "$?" '2'
cpath foo     >/dev/null 2>&1; check "no-slash input exits 2" "$?" '2'

if [ "$fail" -eq 0 ]; then echo "PASS"; exit 0; else echo "FAIL"; exit 1; fi
