# termCopy

When TUI apps like Claude Code render text, they insert hard newlines at the terminal width. Pasting the text results in broken paragraphs with extra line breaks. termCopy watches your clipboard and automatically unwraps terminal-wrapped text while preserving lists, code blocks, and paragraph breaks.

## Install

```
brew install aaronw122/tap/termcopy
brew services start termcopy
```

## What it does

- Runs as a background daemon
- Watches the clipboard using macOS changeCount (no polling of contents — just an integer check every 0.1s)
- Only processes copies from terminal apps (cmux, Ghostty, Terminal, iTerm2, Kitty, WezTerm, Warp, Alacritty)
- Joins lines that were split by terminal wrapping
- Preserves intentional structure: paragraph breaks, numbered/bullet lists, code blocks, headers

## Uninstall

```
brew services stop termcopy
brew uninstall termcopy
```
