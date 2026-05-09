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

## How it works

Terminal text wrapping inserts real newline characters that are indistinguishable from intentional line breaks. termCopy uses heuristics to tell them apart:

- Lines at the detected terminal width are joined (terminal wrap)
- Lines ending with : are kept (introducing a list/block)
- Sentence-ending punctuation + uppercase next line is kept (new paragraph)
- List items, code fences, headers, blank lines are always preserved
- Short lines (< 45 chars) are kept (intentional break)

## Uninstall

```
brew services stop termcopy
brew uninstall termcopy
```
