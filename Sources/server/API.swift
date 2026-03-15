import Vapor

/// Request/Response models for the API

struct FormulaRequest: Content {
    let elements: [String]
}

struct FormulaResponse: Content {
    let formula: String
}

struct BalanceRequest: Content {
    let equation: String
}

struct BalanceResponse: Content {
    let balanced: String
}

struct MoleculeResponse: Content {
    let name: String
    let formula: String
    let smiles: String
}
