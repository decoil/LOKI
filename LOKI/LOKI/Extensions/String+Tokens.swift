import Foundation

// MARK: - String Token Utilities

extension String {
    /// Rough token count estimate (4 chars per token average for English).
    var estimatedTokenCount: Int {
        max(1, count / 4)
    }

    /// Truncate to approximate token limit.
    func truncatedToTokens(_ maxTokens: Int) -> String {
        let maxChars = maxTokens * 4
        if count <= maxChars { return self }
        return String(prefix(maxChars)) + "..."
    }

    /// Strip XML/HTML-like tags.
    var strippingTags: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    /// Extract content between tags.
    func extractBetween(open: String, close: String) -> String? {
        guard let openRange = range(of: open),
              let closeRange = range(of: close, range: openRange.upperBound..<endIndex) else {
            return nil
        }
        return String(self[openRange.upperBound..<closeRange.lowerBound])
    }
}
