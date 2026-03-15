import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// ChemiGenerator — proxies to SiliconFlow API
/// Interprets natural language chemistry descriptions and returns structured JSON.
struct AIAssistant {

    static let apiURL = "https://api.siliconflow.cn/v1/chat/completions"
    static let apiKey = "sk-rxdkwdcxdnzunjjjcczkpzgaybzyunbehakjshmlehlyoain"
    static let model = "deepseek-ai/DeepSeek-V3.1-Terminus"

    /// System prompt that instructs the model to return structured chemistry JSON
    static let systemPrompt = """
    Chemistry generator. Return ONLY valid JSON with these fields:
    name(string|null), formula(string|null), latex(string|null), structural_latex(string|null), markdown(string|null), smiles(string|null), reaction(string|null), products(string[]|[]), explanation(string|null), type("organic"|"inorganic"|"reaction"|"error"), error_message(string|null).

    Rules: Non-chemistry input→type="error". Organic→MUST include valid SMILES and structural_latex. latex=molecular formula LaTeX. structural_latex=structural formula in LaTeX using \\\\ce{} or chemfig-style notation showing bonds (e.g. C_6H_5COOH for benzoic acid). For inorganic, structural_latex=null. Multi-digit subscripts use braces: C_{10}. No code fences. No comments.

    Example: {"name":"benzene","formula":"C6H6","latex":"\\\\mathrm{C_6H_6}","structural_latex":"\\\\ce{C6H6}","markdown":"$C_6H_6$","smiles":"c1ccccc1","reaction":null,"products":[],"explanation":"Aromatic hydrocarbon.","type":"organic","error_message":null}
    """

    /// Response structure
    struct AIChemResponse: Codable {
        let name: String?
        let formula: String?
        let latex: String?
        let structural_latex: String?
        let markdown: String?
        let smiles: String?
        let reaction: String?
        let products: [String]?
        let explanation: String?
        let type: String?
        let error_message: String?
    }

    /// Call the SiliconFlow API and return parsed chemistry JSON
    static func query(input: String, language: String = "en") async throws -> AIChemResponse {
        guard let url = URL(string: apiURL) else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let langInstruction = language == "cn"
            ? "\n\nIMPORTANT: The 'explanation' and 'name' fields MUST be written in Chinese (简体中文). The 'error_message' field must also be in Chinese."
            : "\n\nIMPORTANT: The 'explanation' and 'name' fields MUST be written in English."

        let fullPrompt = systemPrompt + langInstruction

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": fullPrompt],
                ["role": "user", "content": input]
            ],
            "temperature": 0.2,
            "max_tokens": 512,
            "enable_thinking": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyStr = String(data: data, encoding: .utf8) ?? "no body"
            throw AIError.apiError(statusCode: statusCode, message: bodyStr)
        }

        // Parse the API response to extract the assistant's message content
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError("Could not extract content from API response")
        }

        // The content should be JSON — parse it
        let chemJSON = extractJSON(from: content)
        guard let chemData = chemJSON.data(using: .utf8) else {
            throw AIError.parseError("Could not convert content to data")
        }

        let decoder = JSONDecoder()
        let chemResponse = try decoder.decode(AIChemResponse.self, from: chemData)
        return chemResponse
    }

    /// Extract JSON from a string that might contain markdown code fences, comments, or other noise
    private static func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code fences if present
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to find JSON object boundaries { ... }
        if let startIdx = cleaned.firstIndex(of: "{"),
           let endIdx = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIdx...endIdx])
        }

        // Remove single-line comments (// ...) that break JSON parsing
        let lines = cleaned.components(separatedBy: "\n")
        let filteredLines = lines.map { line -> String in
            // Remove // comments but not inside strings
            var inString = false
            var escaped = false
            var result = ""
            let chars = Array(line)
            var i = 0
            while i < chars.count {
                let ch = chars[i]
                if escaped {
                    result.append(ch)
                    escaped = false
                    i += 1
                    continue
                }
                if ch == "\\" && inString {
                    result.append(ch)
                    escaped = true
                    i += 1
                    continue
                }
                if ch == "\"" {
                    inString = !inString
                    result.append(ch)
                    i += 1
                    continue
                }
                if !inString && ch == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                    break // rest of line is comment
                }
                result.append(ch)
                i += 1
            }
            return result
        }
        cleaned = filteredLines.joined(separator: "\n")

        // Remove trailing commas before } or ]
        cleaned = cleaned.replacingOccurrences(
            of: ",\\s*([}\\]])",
            with: "$1",
            options: .regularExpression
        )

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum AIError: Error, CustomStringConvertible {
        case invalidURL
        case apiError(statusCode: Int, message: String)
        case parseError(String)

        var description: String {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .apiError(let code, let msg): return "API error (\(code)): \(msg)"
            case .parseError(let msg): return "Parse error: \(msg)"
            }
        }
    }
}
