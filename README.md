# `cpath`

> *convert path*

A 12-line bash function for WSL that auto-detects whether you handed it a Windows or a WSL path and converts it the other way. The result is printed and also copied to the Windows clipboard so you can paste it straight into File Explorer, an editor, or a chat.

It's a thin wrapper around Microsoft's built-in [`wslpath`](https://learn.microsoft.com/en-us/windows/wsl/filesystems) plus Windows' built-in `clip.exe`. No PHP, Python, Go, or Rust runtime — just bash and two tools that already ship with WSL and Windows.

## Install / update

```bash
curl -fsSL https://raw.githubusercontent.com/max-nothacker/cpath/main/install.sh | bash
source ~/.bashrc
```

Re-run the same command to update — the installer is idempotent and never duplicates anything in `~/.bashrc`.

What it does:

- Writes `cpath.sh` to `~/.local/share/cpath/cpath.sh`.
- Adds one tagged source-line to `~/.bashrc` (and `~/.zshrc` if it exists) so every new shell picks it up.
- Migrates legacy installs (an embedded `cpath()` block from earlier versions of this README) — backup saved at `<rc>.cpath-bak`.

Prefer to read the script before running it:

```bash
curl -fsSL https://raw.githubusercontent.com/max-nothacker/cpath/main/install.sh -o /tmp/cpath-install.sh
less /tmp/cpath-install.sh
bash /tmp/cpath-install.sh
source ~/.bashrc
```

**Dotfile users:** copy [`cpath.sh`](./cpath.sh) anywhere you like and `source` it directly from your shell rc — no installer needed.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/max-nothacker/cpath/main/uninstall.sh | bash
```

Removes the source-line from `~/.bashrc` and `~/.zshrc` (backups at `<rc>.cpath-bak`) and deletes `~/.local/share/cpath`.

## Usage

```bash
$ cpath 'C:\path\to\folder'
/mnt/c/path/to/folder
# (and the same string is on the Windows clipboard)

$ cpath /home/user/repos
\\wsl.localhost\Ubuntu\home\user\repos
# (paste into File Explorer's address bar to open the WSL folder)

$ cpath /mnt/c/Users/Public
C:\Users\Public

# From a pipe (first line of stdin)
$ pwd | cpath
\\wsl.localhost\Ubuntu\home\user

# From the Windows clipboard (no args)
# 1. Right-click a file in File Explorer → "Copy as path"
# 2. In WSL:
$ cpath
/mnt/c/Users/you/something.txt
# (same string is now back on the clipboard, ready to paste)
```

The clipboard mode side-steps bash's backslash-eating problem entirely: paths copied from Explorer never touch the shell's argument parser, so you don't have to remember to single-quote them.

## How it works

1. A regex checks whether the input starts with `<letter>:[\/]` or `\\` → treats it as Windows and calls `wslpath -u`.
2. Anything else is treated as a WSL path and converted with `wslpath -w` (backslash form — what File Explorer wants).
3. The result is piped through `clip.exe`, which Windows exposes to WSL via interop.

That's the whole tool.

## Prior art

`cpath` is a thin combination of two well-known pieces. Credit where it's due:

- [`laurent22/wslpath`](https://github.com/laurent22/wslpath) — PHP, auto-detects direction.
- [`lamyj/wsl-path-converter`](https://github.com/lamyj/wsl-path-converter) — Python (`wpc`), auto-detects.
- [`ardnew/wslpath`](https://github.com/ardnew/wslpath) — Go binary, auto-detects, actively maintained.

The niche `cpath` fills: auto-detect **plus** Windows clipboard **plus** zero non-Microsoft dependencies, in a function small enough to drop into `~/.bashrc`.

## License

MIT — see [LICENSE](./LICENSE).
