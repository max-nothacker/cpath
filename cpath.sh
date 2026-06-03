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
  if [ "$#" -eq 0 ]; then
    echo "usage: cpath <path>" >&2
    return 2
  fi
  local in="$*"
  local out
  if [[ "$in" =~ ^[A-Za-z]:[\\/] ]] || [[ "$in" =~ ^\\\\ ]]; then
    out=$(wslpath -u "$in") || return $?
  else
    out=$(wslpath -w "$in") || return $?
  fi
  printf '%s\n' "$out"
  printf '%s' "$out" | clip.exe
}
