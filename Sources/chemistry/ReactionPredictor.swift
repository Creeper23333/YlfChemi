import Foundation

/// Predicts common reaction products from given reactants.
/// Uses a rule-based approach with known reaction patterns.
struct ReactionPredictor {

    struct Suggestion: Codable {
        let products: [String]
        let equation: String
    }

    /// Given reactant formulas, suggest possible products
    static func predict(reactants: [String]) -> [Suggestion] {
        let sorted = reactants.map { $0.trimmingCharacters(in: .whitespaces) }.sorted()
        let key = sorted.joined(separator: "+")

        // Look up known reactions
        if let known = knownReactions[key] {
            return known
        }

        // Try matching patterns
        var suggestions: [Suggestion] = []

        // Metal + non-metal -> ionic compound
        if sorted.count == 2 {
            let el1 = ElementDB.lookup(sorted[0])
            let el2 = ElementDB.lookup(sorted[1])
            if let e1 = el1, let e2 = el2 {
                let formula = FormulaGenerator.generate(elements: [e1.symbol, e2.symbol])
                if !formula.formula.starts(with: "Error") {
                    suggestions.append(Suggestion(
                        products: [formula.formula],
                        equation: "\(sorted[0]) + \(sorted[1]) → \(formula.formula)"
                    ))
                }
            }
        }

        return suggestions
    }

    // ── Known reaction database ─────────────────────
    // Key format: reactants sorted alphabetically, joined by "+"

    static let knownReactions: [String: [Suggestion]] = [
        // Combustion reactions
        "C+O2": [
            Suggestion(products: ["CO2"], equation: "C + O2 → CO2"),
            Suggestion(products: ["CO"], equation: "2C + O2 → 2CO")
        ],
        "CH4+O2": [
            Suggestion(products: ["CO2", "H2O"], equation: "CH4 + 2O2 → CO2 + 2H2O")
        ],
        "C2H6O+O2": [
            Suggestion(products: ["CO2", "H2O"], equation: "C2H6O + 3O2 → 2CO2 + 3H2O")
        ],

        // Synthesis reactions
        "H2+O2": [
            Suggestion(products: ["H2O"], equation: "2H2 + O2 → 2H2O")
        ],
        "N2+H2": [
            Suggestion(products: ["NH3"], equation: "N2 + 3H2 → 2NH3")
        ],
        "Na+Cl2": [
            Suggestion(products: ["NaCl"], equation: "2Na + Cl2 → 2NaCl")
        ],
        "Cl+Na": [
            Suggestion(products: ["NaCl"], equation: "Na + Cl → NaCl")
        ],
        "Na+Cl": [
            Suggestion(products: ["NaCl"], equation: "Na + Cl → NaCl")
        ],
        "Fe+O2": [
            Suggestion(products: ["Fe2O3"], equation: "4Fe + 3O2 → 2Fe2O3"),
            Suggestion(products: ["Fe3O4"], equation: "3Fe + 2O2 → Fe3O4")
        ],
        "Al+O2": [
            Suggestion(products: ["Al2O3"], equation: "4Al + 3O2 → 2Al2O3")
        ],
        "Mg+O2": [
            Suggestion(products: ["MgO"], equation: "2Mg + O2 → 2MgO")
        ],
        "Ca+O2": [
            Suggestion(products: ["CaO"], equation: "2Ca + O2 → 2CaO")
        ],

        // Acid-base
        "HCl+NaOH": [
            Suggestion(products: ["NaCl", "H2O"], equation: "HCl + NaOH → NaCl + H2O")
        ],
        "H2SO4+NaOH": [
            Suggestion(products: ["Na2SO4", "H2O"], equation: "H2SO4 + 2NaOH → Na2SO4 + 2H2O")
        ],

        // Decomposition
        "H2O2": [
            Suggestion(products: ["H2O", "O2"], equation: "2H2O2 → 2H2O + O2")
        ],
        "CaCO3": [
            Suggestion(products: ["CaO", "CO2"], equation: "CaCO3 → CaO + CO2")
        ],
    ]
}
