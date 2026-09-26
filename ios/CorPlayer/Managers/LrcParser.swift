import Foundation

class LrcParser {
    /// 解析LRC歌词，返回 [(时间, 文本)] 按时间排序
    static func parse(_ lrc: String) -> [(time: TimeInterval, text: String)] {
        var lines: [(TimeInterval, String)] = []
        let regex = try? NSRegularExpression(pattern: "\\[(\\d{1,2}):(\\d{1,2})(?:\\.(\\d{1,3}))?\\]", options: [])
        for line in lrc.components(separatedBy: .newlines) {
            guard let regex = regex else { continue }
            let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count))
            guard !matches.isEmpty else { continue }
            // 文本部分：最后一个时间标签之后的内容
            var text = line
            if let lastMatch = matches.last {
                let endIndex = lastMatch.range.location + lastMatch.range.length
                if endIndex < line.utf16.count {
                    text = String(line[line.index(line.startIndex, offsetBy: endIndex)...])
                } else { text = "" }
            }
            text = text.trimmingCharacters(in: .whitespaces)
            for match in matches {
                if let minRange = Range(match.range(at: 1), in: line),
                   let secRange = Range(match.range(at: 2), in: line) {
                    let min = Int(line[minRange]) ?? 0
                    let sec = Int(line[secRange]) ?? 0
                    var ms = 0
                    if match.numberOfRanges > 3, let msRange = Range(match.range(at: 3), in: line) {
                        ms = Int(line[msRange]) ?? 0
                    }
                    let time = TimeInterval(min * 60 + sec) + TimeInterval(ms) / 1000.0
                    lines.append((time, text))
                }
            }
        }
        return lines.sorted(by: { $0.0 < $1.0 })
    }
}
