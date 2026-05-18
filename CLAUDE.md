# termCopy

macOS clipboard utility that fixes copy-paste from terminal apps by unwrapping TUI-inserted line breaks. Written in Swift.

## Release Process

After merging PRs to `main`, the Homebrew tap must be updated manually:

1. **Tag the release:** `git tag vX.Y.Z && git push origin vX.Y.Z`
2. **Create GitHub release:** `gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."`
3. **Get the tarball sha256:** `curl -sL https://github.com/aaronw122/termcopy/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256`
4. **Update the Homebrew formula** in `aaronw122/homebrew-tap` (`Formula/termcopy.rb`) — update the `url` tag version and `sha256`
5. **Merge the tap PR**

The Homebrew tap lives at: https://github.com/aaronw122/homebrew-tap
Install command: `brew install aaronw122/tap/termcopy`
