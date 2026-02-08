import Foundation

// MARK: - Web Search Tool

struct WebSearchTool: AgentTool {
    let name = "web_search"
    let description = "Search the web for information. Returns a summary of search results."

    let parametersSchema = ToolParametersSchema(
        type: "object",
        properties: [
            "query": .init(
                type: "string",
                description: "The search query"
            ),
            "num_results": .init(
                type: "integer",
                description: "Number of results to return (1-5, default 3)"
            ),
        ],
        required: ["query"]
    )

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        guard let query = arguments["query"] as? String, !query.isEmpty else {
            throw ToolError.invalidArguments("'query' is required and must be non-empty")
        }

        let numResults = min(arguments["num_results"] as? Int ?? 3, 5)

        // Use DuckDuckGo HTML endpoint (no API key required)
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://html.duckduckgo.com/html/?q=\(encoded)"

        guard let url = URL(string: urlString) else {
            return .error("Failed to construct search URL")
        }

        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
                forHTTPHeaderField: "User-Agent"
            )

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .error("Search request failed")
            }

            let html = String(data: data, encoding: .utf8) ?? ""
            let results = parseSearchResults(html: html, limit: numResults)

            if results.isEmpty {
                return .success("No results found for: \(query)")
            }

            let formatted = results.enumerated().map { index, result in
                "\(index + 1). \(result.title)\n   \(result.snippet)\n   URL: \(result.url)"
            }.joined(separator: "\n\n")

            return .success("Search results for \"\(query)\":\n\n\(formatted)")
        } catch {
            return .error("Search failed: \(error.localizedDescription)")
        }
    }

    // MARK: - HTML Parsing

    private struct SearchResult {
        let title: String
        let snippet: String
        let url: String
    }

    private func parseSearchResults(html: String, limit: Int) -> [SearchResult] {
        var results: [SearchResult] = []

        // Simple regex-based extraction from DuckDuckGo HTML results
        let titlePattern = #"class="result__a"[^>]*>([^<]+)</a>"#
        let snippetPattern = #"class="result__snippet"[^>]*>([^<]+)"#
        let urlPattern = #"class="result__url"[^>]*>([^<]+)"#

        let titles = matches(for: titlePattern, in: html)
        let snippets = matches(for: snippetPattern, in: html)
        let urls = matches(for: urlPattern, in: html)

        let count = min(limit, min(titles.count, min(snippets.count, urls.count)))
        for i in 0..<count {
            results.append(SearchResult(
                title: titles[i].trimmingCharacters(in: .whitespacesAndNewlines),
                snippet: snippets[i].trimmingCharacters(in: .whitespacesAndNewlines),
                url: urls[i].trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        return results
    }

    private func matches(for pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[captureRange])
        }
    }
}
