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
    You are a professional chemistry formula and reaction generator.

    Your job is to interpret a user's natural language description of a chemical formula, compound, or reaction.

    You must return structured JSON only.

    The JSON must include ALL of these fields (use null for inapplicable ones):

    - name: compound name (string or null)
    - formula: molecular formula like "C6H6" or "H2O" (string or null). IMPORTANT: for numbers >= 10, write them fully, e.g. "C10H10O4" not "C1OH1OO4"
    - latex: LaTeX notation like "\\\\mathrm{C_6H_6}" (string or null)
    - markdown: Markdown math like "$C_6H_6$" (string or null)
    - smiles: SMILES notation for the molecule (string or null). You MUST provide SMILES for ALL organic compounds.
    - reaction: balanced equation like "4Fe + 3O2 -> 2Fe2O3" (string or null)
    - products: array of product formulas (array or empty array)
    - explanation: brief explanation of the compound/reaction (string or null)
    - type: either "organic", "inorganic", "reaction", or "error" (string, REQUIRED)
    - error_message: error description if input is not chemistry-related (string or null)

    Rules:

    1. FIRST determine if the input is chemistry-related. If NOT (e.g. person names, places, random words, non-chemistry topics), return type="error" with error_message explaining it's not a valid chemistry query. Set all other fields to null.
    2. If the user describes a molecule, determine if it's organic or inorganic and set type accordingly.
    3. For ORGANIC compounds (type="organic"), you MUST provide a valid SMILES string. This is critical.
    4. For inorganic compounds (type="inorganic"), smiles should be null.
    5. For reactions (type="reaction"), provide the balanced equation.
    6. Always generate LaTeX chemical notation using \\\\mathrm{} format.
    7. Always generate Markdown math notation.
    8. Return ONLY JSON. No explanations outside JSON. No markdown code fences.
    9. For subscript numbers in LaTeX, use underscore with braces for multi-digit: C_{10} not C_10 for numbers >= 10.

    Example organic molecule response:
    {
      "name": "Dimethyl terephthalate",
      "formula": "C10H10O4",
      "latex": "\\\\mathrm{C_{10}H_{10}O_4}",
      "markdown": "$C_{10}H_{10}O_4$",
      "smiles": "COC(=O)c1ccc(C(=O)OC)cc1",
      "reaction": null,
      "products": [],
      "explanation": "Dimethyl terephthalate is an organic compound used as a precursor in PET plastic production.",
      "type": "organic",
      "error_message": null
    }

    Example inorganic molecule response:
    {
      "name": "Water",
      "formula": "H2O",
      "latex": "\\\\mathrm{H_2O}",
      "markdown": "$H_2O$",
      "smiles": null,
      "reaction": null,
      "products": [],
      "explanation": "Water is a common inorganic compound.",
      "type": "inorganic",
      "error_message": null
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
      "explanation": "Iron reacts with oxygen to form iron(III) oxide.",
      "type": "reaction",
      "error_message": null
    }

    Example error response (non-chemistry input):
    {
      "name": null,
      "formula": null,
      "latex": null,
      "markdown": null,
      "smiles": null,
      "reaction": null,
      "products": [],
      "explanation": null,
      "type": "error",
      "error_message": "The input does not appear to be a chemistry-related query. Please enter a chemical compound name, formula, or reaction description."
    }
    """

    /// Response structure
    struct AIChemResponse: Codable {
        let name: String?
        let formula: String?
        let latex: String?
        let markdown: String?
        let smiles: String?
        let reaction: String?
        let products: [String]?
        let explanation: String?
        let type: String?
        let error_message: String?
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
