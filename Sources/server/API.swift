import Vapor

/// Request/Response models for the API

// ── Formula Builder ─────────────────────────

struct FormulaBuildRequest: Content {
    let elements: [FormulaBuilder.ElementEntry]
}

struct FormulaBuildResponse: Content {
    let formula: String
    let latex: String
    let markdown: String
    let katex: String
    let display: String  // Unicode subscript version
}

// ── Legacy Formula (valence cross) ──────────

struct FormulaRequest: Content {
    let elements: [String]
}

struct FormulaResponse: Content {
    let formula: String
}

// ── Equation Balancer ───────────────────────

struct BalanceRequest: Content {
    let equation: String
}

struct BalanceResponse: Content {
    let balanced: String
    let latex: String
    let markdown: String
    let katex: String
}

// ── Reaction Predictor ──────────────────────

struct PredictRequest: Content {
    let reactants: [String]
}

struct PredictResponse: Content {
    let suggestions: [ReactionPredictor.Suggestion]
}

// ── Organic Database ────────────────────────

struct MoleculeResponse: Content {
    let name: String
    let formula: String
    let smiles: String
}
