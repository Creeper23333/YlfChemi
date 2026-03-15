import Foundation

/// Generates inorganic chemical formulas using the valence cross method.
///
/// Algorithm:
/// 1. Look up valences for both elements
/// 2. Use the "criss-cross" method: each element's subscript = other element's valence
/// 3. Simplify by dividing by GCD
struct FormulaGenerator {

    struct Result {
        let formula: String
    }

    static func generate(elements: [String]) -> Result {
        guard elements.count == 2 else {
            return Result(formula: "Error: provide exactly 2 elements")
        }

        let sym1 = elements[0].trimmingCharacters(in: .whitespaces)
        let sym2 = elements[1].trimmingCharacters(in: .whitespaces)

        guard let el1 = ElementDB.lookup(sym1),
              let el2 = ElementDB.lookup(sym2) else {
            return Result(formula: "Error: unknown element(s)")
        }

        // Determine which is the "cation" (metal/positive) and "anion" (non-metal/negative)
        let (cation, anion) = orderElements(el1, el2)

        // Use first (most common) valence for each
        let v1 = cation.valence[0]
        let v2 = anion.valence[0]

        // Criss-cross: subscript of cation = anion's valence, and vice versa
        let g = gcd(v1, v2)
        let sub1 = v2 / g
        let sub2 = v1 / g

        // Build formula string
        var formula = cation.symbol
        if sub1 > 1 { formula += "\(sub1)" }
        formula += anion.symbol
        if sub2 > 1 { formula += "\(sub2)" }

        return Result(formula: formula)
    }

    /// Order elements: metal (cation) first, non-metal (anion) second.
    /// If both are non-metals, use conventional ordering (less electronegative first).
    private static func orderElements(_ a: Element, _ b: Element) -> (Element, Element) {
        if a.isMetal && !b.isMetal { return (a, b) }
        if b.isMetal && !a.isMetal { return (b, a) }
        // Both metals or both non-metals — keep original order
        return (a, b)
    }

    /// Greatest common divisor (Euclidean algorithm)
    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var (a, b) = (a, b)
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }
}
