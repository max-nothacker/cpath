# cpath — convert path
#
# Tiny WSL bash function. Converts a path between three forms — a Windows path,
# a WSL path, and a file:// URL — using Microsoft's built-in `wslpath`. The
# result is printed AND copied to the Windows clipboard via `clip.exe`.
#
# With no target flag it converts along this graph:
#   file:// URL  ->  Windows
#   Windows      ->  WSL
#   WSL          ->  Windows
# Pass a target flag to convert to a specific form instead:
#   -i / --windows   ->  Windows path
#   -s / --wsl       ->  WSL path
#   -f / --fileurl   ->  file:// URL
#
# Install:
#   curl -fsSL https://raw.githubusercontent.com/max-nothacker/cpath/main/install.sh | bash
#
# Usage:
#   cpath 'C:\path\to\folder'        # -> /mnt/c/path/to/folder
#   cpath /home/user/repos           # -> \\wsl.localhost\<distro>\home\user\repos
#   cpath 'file:///C:/a%20b/x.pdf'   # -> C:\a b\x.pdf
#   cpath -f /home/user/notes        # -> file://wsl.localhost/<distro>/home/user/notes
#   cpath -s 'C:\path'               # force WSL form
#   <command> | cpath                # convert the first line of stdin
#   cpath                            # convert the Windows clipboard contents
#
# License: MIT

# Percent-decode a string (e.g. %20 -> space). Used to parse file:// URLs.
__cpath_url_decode() {
  # Turn every %XX into \xXX, then let printf %b decode the bytes.
  printf '%b' "${1//%/\\x}"
}

# Percent-encode a path for a file:// URL. Preserves a path's structural
# characters (/ : - . _ ~ and alphanumerics); encodes everything else
# (spaces -> %20, etc.).
__cpath_url_encode() {
  local s="$1" out='' c i
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [A-Za-z0-9/:._~-]) out+="$c" ;;
      *) printf -v c '%%%02X' "'$c"; out+="$c" ;;
    esac
  done
  printf '%s' "$out"
}

# file:// URL -> Windows path (backslash form).
__cpath_url_to_win() {
  local body
  body="$(__cpath_url_decode "${1#[Ff][Ii][Ll][Ee]:}")"
  case "$body" in
    ///*) body="${body#///}" ;;     # file:///C:/..  (empty host) -> drive path
    //*)  body="\\\\${body#//}" ;;  # file://host/.. -> \\host\.. (UNC)
    /*)   body="${body#/}" ;;       # file:/C:/..    (host omitted)
  esac
  printf '%s' "${body//\//\\}"      # forward slashes -> backslashes
}

# Windows path (backslash form) -> file:// URL.
__cpath_win_to_url() {
  local p
  p="$(__cpath_url_encode "${1//\\//}")"  # backslashes -> forward slashes, then encode
  case "$1" in
    \\\\*) printf 'file:%s' "$p" ;;     # \\host\.. -> //host/.. -> file://host/..
    *)     printf 'file:///%s' "$p" ;;  # C:\..     -> C:/..     -> file:///C:/..
  esac
}

cpath() {
  local to='' in

  # Optional leading target flag. Real Windows/WSL/file paths never start with
  # '-', so a leading dash is unambiguously a flag, not part of the path.
  case "${1:-}" in
    -i|--windows) to=windows; shift ;;
    -s|--wsl)     to=wsl;     shift ;;
    -f|--fileurl) to=fileurl; shift ;;
    -h|--help)
      cat >&2 <<'EOF'
cpath — convert a path between Windows, WSL, and file:// forms.

Usage: cpath [-i|-s|-f] [PATH...]

  no flag          convert along the default graph:
                     file:// -> Windows,  Windows -> WSL,  WSL -> Windows
  -i, --windows    convert to a Windows path
  -s, --wsl        convert to a WSL path
  -f, --fileurl    convert to a file:// URL

With no PATH it reads the first line of stdin, or the Windows clipboard.
The result is printed and copied to the Windows clipboard.
EOF
      return 0 ;;
    -*) printf "cpath: unknown option '%s' (try -i, -s, -f, or -h)\n" "$1" >&2; return 2 ;;
  esac

  if [ "$#" -eq 0 ]; then
    if [ -t 0 ]; then
      # No arg, no pipe — read the Windows clipboard.
      in=$(powershell.exe -NoProfile -Command Get-Clipboard 2>/dev/null | head -n 1 | tr -d '\r')
      if [ -z "$in" ]; then
        echo "cpath: no arguments and the Windows clipboard is empty." >&2
        echo "       Either copy a Windows, WSL, or file:// path to your clipboard and re-run," >&2
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

  # Determine the source form.
  local src
  if [[ "$in" =~ ^[Ff][Ii][Ll][Ee]:// ]]; then
    src=fileurl
  elif [[ "$in" =~ ^[A-Za-z]:[\\/] ]] || [[ "$in" =~ ^\\\\ ]]; then
    src=windows
  else
    # Not a file URL, drive path, or UNC path. If it has no slash at all, the
    # shell almost certainly stripped backslashes from an unquoted Windows path
    # (bash eats backslashes outside of single quotes). Recovery is impossible.
    if [[ ! "$in" =~ [\\/] ]]; then
      echo "cpath: input '$in' contains no slashes." >&2
      echo "       Your shell likely stripped backslashes from an unquoted Windows path." >&2
      echo "       Two ways to fix this:" >&2
      echo "         a) Wrap the path in single quotes:  cpath 'C:\\path\\to\\folder'" >&2
      echo "         b) Copy the path to your clipboard, then run cpath with no arguments." >&2
      return 2
    fi
    src=wsl
  fi

  # No explicit target -> follow the default conversion graph.
  if [ -z "$to" ]; then
    case "$src" in
      fileurl) to=windows ;;
      windows) to=wsl ;;
      wsl)     to=windows ;;
    esac
  fi

  # Resolve the input to a Windows path once; every target derives from it.
  local win out
  case "$src" in
    fileurl) win=$(__cpath_url_to_win "$in") ;;
    windows) win=${in//\//\\} ;;                 # normalize any forward slashes
    wsl)     win=$(wslpath -w "$in") || return $? ;;
  esac

  case "$to" in
    windows) out=$win ;;
    wsl)     out=$(wslpath -u "$win") || return $? ;;
    fileurl) out=$(__cpath_win_to_url "$win") ;;
  esac

  printf '%s\n' "$out"
  printf '%s' "$out" | clip.exe
}
