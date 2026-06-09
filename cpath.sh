# cpath — convert path
#
# Tiny WSL bash function. Auto-detects whether the argument is a Windows or
# WSL path and converts it via Microsoft's built-in `wslpath`. The result is
# printed AND copied to the Windows clipboard via `clip.exe`.
#
# Install:
#   curl -fsSL https://raw.githubusercontent.com/max-nothacker/cpath/main/install.sh | bash
#
# Usage:
#   cpath 'C:\path\to\folder'   # -> /mnt/c/path/to/folder
#   cpath /home/user/repos      # -> \\wsl.localhost\<distro>\home\user\repos
#   <command> | cpath           # convert the first line of stdin
#   cpath                       # convert the Windows clipboard contents
#
# License: MIT

cpath() {
  local in
  if [ "$#" -eq 0 ]; then
    if [ -t 0 ]; then
      # No arg, no pipe — read the Windows clipboard.
      in=$(powershell.exe -NoProfile -Command Get-Clipboard 2>/dev/null | head -n 1 | tr -d '\r')
      if [ -z "$in" ]; then
        echo "cpath: no arguments and the Windows clipboard is empty." >&2
        echo "       Either copy a Windows or WSL path to your clipboard and re-run," >&2
        echo "       or pass the path explicitly:  cpath 'C:\\path\\to\\folder'" >&2
        return 2
      fi
    else
      # read first line of stdin; -r preserves backslashes; IFS= keeps whitespace
      IFS= read -r in || true
    fi
  else
    in="$*"
  fi
  # strip any trailing CR (Windows tools sometimes pipe \r\n)
  in="${in%$'\r'}"
  if [ -z "$in" ]; then
    echo "cpath: empty input" >&2
    return 2
  fi
  # If the input has no slashes at all, the shell almost certainly stripped
  # backslashes from an unquoted Windows path (bash eats backslashes outside
  # of single quotes). Recovery is impossible — point at both workarounds.
  if [[ ! "$in" =~ [\\/] ]]; then
    echo "cpath: input '$in' contains no slashes." >&2
    echo "       Your shell likely stripped backslashes from an unquoted Windows path." >&2
    echo "       Two ways to fix this:" >&2
    echo "         a) Wrap the path in single quotes:  cpath 'C:\\path\\to\\folder'" >&2
    echo "         b) Copy the path to your clipboard, then run cpath with no arguments." >&2
    return 2
  fi
  local out
  if [[ "$in" =~ ^[A-Za-z]:[\\/] ]] || [[ "$in" =~ ^\\\\ ]]; then
    out=$(wslpath -u "$in") || return $?
  else
    out=$(wslpath -w "$in") || return $?
  fi
  printf '%s\n' "$out"
  printf '%s' "$out" | clip.exe
}
