import AppKit
import Foundation

// MARK: - Configuration

let maxProcessSize = 100_000

let terminalApps: Set<String> = [
    "com.cmuxterm.app",
    "com.cmuxterm.app.debug",
    "com.mitchellh.ghostty",
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "net.kovidgoyal.kitty",
    "com.github.wez.wezterm",
    "dev.warp.Warp-Stable",
    "io.alacritty",
]

// MARK: - Regex patterns

let fencePattern = try! NSRegularExpression(pattern: #"^\s*(```|~~~)"#)
let headerPattern = try! NSRegularExpression(pattern: #"^\s{0,3}#{1,6}\s+"#)
let hrPattern = try! NSRegularExpression(pattern: #"^\s{0,3}([-*_])(?:\s*\1){2,}\s*$"#)
let listPattern = try! NSRegularExpression(pattern: #"^(\s*)([-*+]|\d+[.)])\s+"#)
let quotePattern = try! NSRegularExpression(pattern: #"^\s*>"#)
let wordHyphenPattern = try! NSRegularExpression(pattern: #"[a-zA-Z]-$"#)
let continuationIndentPattern = try! NSRegularExpression(pattern: #"^\s{2,3}\S"#)
let collapseSpacesPattern = try! NSRegularExpression(pattern: #"[ \t]+"#)

func matches(_ pattern: NSRegularExpression, _ string: String) -> Bool {
    pattern.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil
}

// MARK: - Text helpers

func trimTrailing(_ text: String) -> String {
    text.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
}

func normalizeNewlines(_ text: String) -> String {
    text.replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
}

// MARK: - Line classification

func isStandaloneBlock(_ line: String) -> Bool {
    let stripped = trimTrailing(line)
    if stripped.isEmpty { return true }
    if matches(headerPattern, stripped) || matches(hrPattern, stripped) { return true }
    if stripped.hasPrefix("    ") || stripped.hasPrefix("\t") { return true }
    return false
}

func endsSentence(_ line: String) -> Bool {
    let t = trimTrailing(line)
    return t.hasSuffix(".") || t.hasSuffix("!") || t.hasSuffix("?") || t.hasSuffix(";")
}

func estimateWrapWidth(_ lines: [String]) -> Int? {
    let lengths = lines
        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        .map { trimTrailing($0).count }
    guard !lengths.isEmpty else { return nil }

    let width = lengths.max()!
    let nearWidthCount = lengths.filter { $0 >= width - 4 }.count

    if width >= 60 && nearWidthCount >= 2 { return width }
    if width >= 90 { return width }
    return nil
}

// MARK: - Join decision

/// Hard boundaries that should never be joined across.
func isHardBoundary(current: String, next: String) -> Bool {
    if isStandaloneBlock(next) || matches(fencePattern, next) { return true }
    if matches(listPattern, next) { return true }
    if matches(quotePattern, current) != matches(quotePattern, next) { return true }
    if current.hasSuffix(":") { return true }
    return false
}

/// Line reaches the detected terminal width — strongest wrap signal.
func isLikelyTerminalWrap(current: String, width: Int?) -> Bool {
    guard let w = width else { return false }
    return current.count >= max(20, w - 8)
}

/// Sentence-ending punctuation + uppercase next line = new paragraph.
func startsNewParagraph(current: String, nextWithoutIndent: String) -> Bool {
    guard endsSentence(current), let first = nextWithoutIndent.first else { return false }
    return first.isUppercase
}

/// Next line starts lowercase or with opening punctuation — likely a continuation.
func startsLikeContinuation(_ nextWithoutIndent: String) -> Bool {
    guard let first = nextWithoutIndent.first else { return false }
    return first.isLowercase || "([{'\"`".contains(first)
}

func shouldJoin(current currentRaw: String, next nextRaw: String, width: Int?) -> Bool {
    let current = trimTrailing(currentRaw)
    let nextWithoutIndent = String(nextRaw.drop(while: { $0 == " " || $0 == "\t" }))

    guard !current.isEmpty, !nextWithoutIndent.isEmpty else { return false }
    if isHardBoundary(current: current, next: nextRaw) { return false }
    if isLikelyTerminalWrap(current: current, width: width) { return true }
    if startsNewParagraph(current: current, nextWithoutIndent: nextWithoutIndent) { return false }
    if matches(continuationIndentPattern, nextRaw) { return true }
    if matches(wordHyphenPattern, current) { return true }
    if current.count < 45 { return false }
    if startsLikeContinuation(nextWithoutIndent) { return true }
    return !endsSentence(current)
}

// MARK: - Unwrap

func flushProse(_ proseBuffer: inout [String], _ output: inout [String]) {
    guard !proseBuffer.isEmpty else { return }
    let joined = proseBuffer.compactMap { part -> String? in
        let trimmed = part.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }.joined(separator: " ")
    let collapsed = collapseSpacesPattern.stringByReplacingMatches(
        in: joined, range: NSRange(joined.startIndex..., in: joined), withTemplate: " "
    )
    let result = trimTrailing(collapsed)
    if !result.isEmpty {
        output.append(result)
    }
    proseBuffer.removeAll()
}

func unwrap(_ text: String) -> String {
    let lines = normalizeNewlines(text).components(separatedBy: "\n")
    let width = estimateWrapWidth(lines)

    var output: [String] = []
    var proseBuffer: [String] = []
    var inFence = false

    for rawLine in lines {
        let line = trimTrailing(rawLine)

        if matches(fencePattern, line) {
            flushProse(&proseBuffer, &output)
            output.append(line)
            inFence.toggle()
            continue
        }

        if inFence || isStandaloneBlock(line) {
            flushProse(&proseBuffer, &output)
            output.append(line)
            continue
        }

        if matches(listPattern, line) {
            flushProse(&proseBuffer, &output)
            proseBuffer.append(line)
            continue
        }

        if !proseBuffer.isEmpty && shouldJoin(current: proseBuffer.last!, next: line, width: width) {
            proseBuffer.append(line)
        } else {
            flushProse(&proseBuffer, &output)
            proseBuffer.append(line)
        }
    }

    flushProse(&proseBuffer, &output)
    return output.joined(separator: "\n")
}

// MARK: - Clipboard

func getClipboardText() -> String? {
    NSPasteboard.general.string(forType: .string)
}

func setClipboardText(_ text: String) {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(text, forType: .string)
}

func frontmostAppBundleID() -> String? {
    NSWorkspace.shared.frontmostApplication?.bundleIdentifier
}

// MARK: - Modes

func testMode() {
    guard let text = getClipboardText(), !text.isEmpty else {
        print("Clipboard is empty.")
        return
    }

    print("=== Original ===")
    print(String(text.prefix(500)))
    print()

    let result = unwrap(text)
    if result == text {
        print("No changes.")
    } else {
        print("=== Unwrapped ===")
        print(String(result.prefix(500)))
    }
}

func processClipboardChange(pasteboard: NSPasteboard, lastChangeCount: inout Int) {
    guard let current = getClipboardText() else { return }
    guard let app = frontmostAppBundleID(), terminalApps.contains(app) else { return }
    guard current.count <= maxProcessSize else { return }

    let result = unwrap(current)
    guard result != current else { return }

    setClipboardText(result)
    lastChangeCount = pasteboard.changeCount

    let linesBefore = current.components(separatedBy: "\n").count
    let linesAfter = result.components(separatedBy: "\n").count
    print("Unwrapped: \(linesBefore) lines → \(linesAfter) lines (from \(app))")
}

func watch() {
    let pasteboard = NSPasteboard.general
    var lastChangeCount = pasteboard.changeCount

    print("termCopy running. Ctrl+C to stop.")
    print("Watching: \(terminalApps.sorted().joined(separator: ", "))")
    print()

    signal(SIGINT) { _ in
        print("\nStopped.")
        exit(0)
    }

    while true {
        usleep(100_000) // 0.1s — only checks changeCount (one integer compare)

        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { continue }
        lastChangeCount = currentChangeCount

        processClipboardChange(pasteboard: pasteboard, lastChangeCount: &lastChangeCount)
    }
}

// MARK: - Entry point

if CommandLine.arguments.contains("--test") {
    testMode()
} else {
    watch()
}
