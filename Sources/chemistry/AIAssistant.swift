import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// AI Chemistry Assistant — proxies to SiliconFlow API (Qwen model)
/// Interprets natural language chemistry descriptions and returns structured JSON.
struct AIAssistant {

    static let apiURL = "https://api.siliconflow.cn/v1/chat/completions"
    static let apiKey = "sk-rxdkwdcxdnzunjjjcczkpzgaybzyunbehakjshmlehlyoain"
    static let model = "deepseek-ai/DeepSeek-V3.1-Terminus"

    /// System prompt that instructs the AI to return structured chemistry JSON
    static let systemPrompt = """
    You are a professional chemistry assistant.

    Your job is to interpret a user's natural language description of a chemical formula, compound, or reaction.

    You must return structured JSON only.

    The JSON must include:

    formula
    latex
    markdown
    smiles
    reaction
    products
    name
    explanation

    Rules:

    1. If the user describes a molecule, return its formula and SMILES.
    2. If the user describes a reaction, return the balanced equation.
    3. Always generate LaTeX chemical notation.
    4. Always generate Markdown math notation.
    5. If the compound is organic and known, include SMILES.
    6. If the input is ambiguous, return your best interpretation.
    7. Return ONLY JSON. No explanations outside JSON. No markdown code fences.

    Example molecule response:
    {
      "name": "benzene",
      "formula": "C6H6",
      "latex": "\\\\mathrm{C_6H_6}",
      "markdown": "$C_6H_6$",
      "smiles": "c1ccccc1",
      "reaction": null,
      "products": [],
      "explanation": "Benzene is an aromatic hydrocarbon."
    }

    Example reaction response:
    {
      "name": null,
      "formula": null,
      "latex": "$$4Fe + 3O_2 \\\\rightarrow 2Fe_2O_3$$",
      "markdown": "$4Fe + 3O_2 → 2Fe_2O_3$",
      "smiles": null,
      "reaction": "4Fe + 3O2 -> 2Fe2O3",
      "products": ["Fe2O3"],
      "explanation": "Iron reacts with oxygen to form iron(III) oxide."
    }
    """

    /// AI response structure
    struct AIChemResponse: Codable {
        let name: String?
        let formula: String?
        let latex: String?
        let markdown: String?
        let smiles: String?
        let reaction: String?
        let products: [String]?
        let explanation: String?
    }

    /// Call the SiliconFlow API and return parsed chemistry JSON
    static func query(input: String) async throws -> AIChemResponse {
        guard let url = URL(string: apiURL) else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ],
            "temperature": 0.3,
            "max_tokens": 1024,
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

    /// Extract JSON from a string that might contain markdown code fences
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
