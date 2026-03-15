import Vapor

/// Request/Response models for the API

// ── ChemiGenerator ──────────────────────────

struct GenerateRequest: Content {
    let input: String
}

struct GenerateResponse: Content {
    let name: String?
    let formula: String?
    let latex: String?
    let markdown: String?
    let smiles: String?
    let reaction: String?
    let products: [String]?
    let explanation: String?
    let type: String?          // "organic", "inorganic", "reaction", "error"
    let error_message: String? // non-nil when type == "error"
    let error: String?         // system-level error (network, parse, etc.)
}
