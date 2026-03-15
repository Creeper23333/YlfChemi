import Foundation

/// Utility for converting chemical formulas and equations to LaTeX format
struct LatexFormatter {

    /// Convert a plain chemical formula to LaTeX
    /// e.g. "H2SO4" -> "H_2SO_4"
    static func formulaToLatex(_ formula: String) -> String {
        var result = ""
        var prevIsLetter = false

        for ch in formula {
            if ch.isNumber && prevIsLetter {
                result += "_\(ch)"
            } else {
                result.append(ch)
            }
            prevIsLetter = ch.isLetter
        }
        return result
    }

    /// Convert a plain chemical formula to LaTeX with \mathrm wrapper
    /// e.g. "H2SO4" -> "\mathrm{H_2SO_4}"
    static func formulaToMathrm(_ formula: String) -> String {
        return "\\mathrm{\(formulaToLatex(formula))}"
    }

    /// Convert a balanced equation to LaTeX
    /// e.g. "4Fe + 3O2 → 2Fe2O3" -> "4Fe + 3O_2 \rightarrow 2Fe_2O_3"
    static func equationToLatex(_ equation: String) -> String {
        let parts = equation.components(separatedBy: "→")
        guard parts.count == 2 else {
            return formulaToLatex(equation)
        }

        let left = parts[0].trimmingCharacters(in: .whitespaces)
        let right = parts[1].trimmingCharacters(in: .whitespaces)

        let leftCompounds = left.components(separatedBy: "+").map {
            formulaToLatex($0.trimmingCharacters(in: .whitespaces))
        }
        let rightCompounds = right.components(separatedBy: "+").map {
            formulaToLatex($0.trimmingCharacters(in: .whitespaces))
        }

        return leftCompounds.joined(separator: " + ") + " \\rightarrow " + rightCompounds.joined(separator: " + ")
    }

    /// Wrap in display math mode
    static func toKatexBlock(_ latex: String) -> String {
        return "$$\(latex)$$"
    }

    /// Wrap in inline math mode
    static func toMarkdownInline(_ latex: String) -> String {
        return "$\(latex)$"
    }
}
