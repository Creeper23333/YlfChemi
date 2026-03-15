import Foundation

/// Builds chemical formulas from element+count pairs.
/// Generates multiple output formats: plain, LaTeX, Markdown, KaTeX.
struct FormulaBuilder {

    struct ElementEntry: Codable {
        let symbol: String
        let count: Int
    }

    struct FormulaOutput: Codable {
        let formula: String
        let latex: String
        let markdown: String
        let katex: String
    }

    /// Build formula from element entries
    /// e.g. [("C",6),("H",6)] -> "C6H6"
    static func build(elements: [ElementEntry]) -> FormulaOutput {
        let plain = buildPlain(elements)
        let latex = buildLatex(elements)
        let markdown = "$\(buildLatexInner(elements))$"
        let katex = "$$\(buildLatexInner(elements))$$"
        return FormulaOutput(formula: plain, latex: latex, markdown: markdown, katex: katex)
    }

    /// Plain formula: C6H6
    private static func buildPlain(_ elements: [ElementEntry]) -> String {
        var result = ""
        for el in elements {
            result += el.symbol
            if el.count > 1 { result += "\(el.count)" }
        }
        return result
    }

    /// LaTeX with \mathrm: \mathrm{C_6H_6}
    private static func buildLatex(_ elements: [ElementEntry]) -> String {
        return "\\mathrm{\(buildLatexInner(elements))}"
    }

    /// Inner LaTeX: C_6H_6
    private static func buildLatexInner(_ elements: [ElementEntry]) -> String {
        var result = ""
        for el in elements {
            result += el.symbol
            if el.count > 1 { result += "_\(el.count)" }
        }
        return result
    }

    /// Convert plain formula string to unicode subscript display
    /// e.g. "C6H6" -> "C₆H₆"
    static func toSubscript(_ formula: String) -> String {
        let subscriptDigits: [Character: Character] = [
            "0": "\u{2080}", "1": "\u{2081}", "2": "\u{2082}", "3": "\u{2083}",
            "4": "\u{2084}", "5": "\u{2085}", "6": "\u{2086}", "7": "\u{2087}",
            "8": "\u{2088}", "9": "\u{2089}"
        ]

        var result = ""
        var prevIsLetter = false

        for ch in formula {
            if ch.isNumber && prevIsLetter {
                result.append(subscriptDigits[ch] ?? ch)
            } else {
                result.append(ch)
            }
            prevIsLetter = ch.isLetter
        }
        return result
    }
}
