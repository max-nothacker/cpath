# cpath — convert path
#
# Tiny WSL bash function. Auto-detects whether the argument is a Windows or
# WSL path and converts it via Microsoft's built-in `wslpath`. The result is
# printed AND copied to the Windows clipboard via `clip.exe`.
#
# Install:
#   curl -fsSL https://raw.githubusercontent.com/max-nothacker/cpath/main/cpath.sh >> ~/.bashrc && source ~/.bashrc
#
# Usage:
#   cpath 'C:\path\to\folder'   # -> /mnt/c/path/to/folder
#   cpath /home/user/repos      # -> \\wsl.localhost\<distro>\home\user\repos
#
# License: MIT

cpath() {
  local in
  if [ "$#" -eq 0 ]; then
    if [ -t 0 ]; then
      echo "usage: cpath <path>   or   <command> | cpath" >&2
      return 2
    fi
    # read first line of stdin; -r preserves backslashes; IFS= keeps whitespace
    IFS= read -r in || true
  else
    in="$*"
  fi
  # strip any trailing CR (Windows tools sometimes pipe \r\n)
  in="${in%$'\r'}"
  if [ -z "$in" ]; then
    echo "cpath: empty input" >&2
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
