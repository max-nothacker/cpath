# `cpath`

> *convert path*

A 12-line bash function for WSL that auto-detects whether you handed it a Windows or a WSL path and converts it the other way. The result is printed and also copied to the Windows clipboard so you can paste it straight into File Explorer, an editor, or a chat.

It's a thin wrapper around Microsoft's built-in [`wslpath`](https://learn.microsoft.com/en-us/windows/wsl/filesystems) plus Windows' built-in `clip.exe`. No PHP, Python, Go, or Rust runtime — just bash and two tools that already ship with WSL and Windows.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/max-nothacker/cpath/main/cpath.sh >> ~/.bashrc && source ~/.bashrc
```

Or copy the function out of [`cpath.sh`](./cpath.sh) into your own dotfiles.

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
```

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
