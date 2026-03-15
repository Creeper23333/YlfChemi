import Foundation

/// Balances chemical equations using linear algebra (Gaussian elimination).
///
/// Algorithm:
/// 1. Parse the equation into reactants and products
/// 2. Extract all unique elements
/// 3. Build a matrix where each column = a compound, each row = an element
///    Reactant coefficients are positive, product coefficients are negative
/// 4. Use Gaussian elimination to find the null space
/// 5. Scale to smallest integer coefficients
struct EquationBalancer {

    static func balance(equation: String) -> BalanceResponse {
        // Normalize arrow
        let normalized = equation
            .replacingOccurrences(of: "->", with: "→")
            .replacingOccurrences(of: "=>", with: "→")
            .replacingOccurrences(of: "=", with: "→")

        guard normalized.contains("→") else {
            return BalanceResponse(balanced: "Error: use '->' to separate reactants and products")
        }

        let sides = normalized.components(separatedBy: "→").map { $0.trimmingCharacters(in: .whitespaces) }
        guard sides.count == 2 else {
            return BalanceResponse(balanced: "Error: invalid equation format")
        }

        let reactants = parseCompounds(sides[0])
        let products = parseCompounds(sides[1])
        let allCompounds = reactants + products

        // Collect all unique elements
        var elementSet: [String] = []
        for compound in allCompounds {
            for (el, _) in compound {
                if !elementSet.contains(el) {
                    elementSet.append(el)
                }
            }
        }

        let numElements = elementSet.count
        let numCompounds = allCompounds.count

        // Build matrix: rows = elements, cols = compounds
        // Reactants get positive values, products get negative
        var matrix = [[Double]](repeating: [Double](repeating: 0, count: numCompounds + 1), count: numElements)

        for (col, compound) in allCompounds.enumerated() {
            let sign: Double = col < reactants.count ? 1.0 : -1.0
            for (element, count) in compound {
                if let row = elementSet.firstIndex(of: element) {
                    matrix[row][col] = sign * Double(count)
                }
            }
        }

        // Gaussian elimination to find null space
        let coefficients = solveNullSpace(matrix: matrix, cols: numCompounds)

        guard let coeffs = coefficients else {
            return BalanceResponse(balanced: "Error: could not balance equation")
        }

        // Build balanced equation string
        let reactantNames = sides[0].components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        let productNames = sides[1].components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }

        var reactantParts: [String] = []
        for (i, name) in reactantNames.enumerated() {
            let c = coeffs[i]
            reactantParts.append(c == 1 ? name : "\(c)\(name)")
        }

        var productParts: [String] = []
        for (i, name) in productNames.enumerated() {
            let c = coeffs[reactants.count + i]
            productParts.append(c == 1 ? name : "\(c)\(name)")
        }

        let result = reactantParts.joined(separator: " + ") + " → " + productParts.joined(separator: " + ")
        return BalanceResponse(balanced: result)
    }

    // ── Parsing ──────────────────────────────────────

    /// Parse "Fe + O2" into [[(element, count)]]
    private static func parseCompounds(_ side: String) -> [[(String, Int)]] {
        let compounds = side.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        return compounds.map { parseCompound($0) }
    }

    /// Parse a single compound like "Fe2O3" into [("Fe", 2), ("O", 3)]
    private static func parseCompound(_ formula: String) -> [(String, Int)] {
        var result: [(String, Int)] = []
        let chars = Array(formula)
        var i = 0

        while i < chars.count {
            // Skip leading coefficient (digits at start)
            if i == 0 && chars[i].isNumber {
                while i < chars.count && chars[i].isNumber { i += 1 }
                continue
            }

            // Element starts with uppercase letter
            guard chars[i].isUppercase else { i += 1; continue }

            var element = String(chars[i])
            i += 1

            // Followed by lowercase letters
            while i < chars.count && chars[i].isLowercase {
                element += String(chars[i])
                i += 1
            }

            // Followed by digits (subscript)
            var numStr = ""
            while i < chars.count && chars[i].isNumber {
                numStr += String(chars[i])
                i += 1
            }

            let count = numStr.isEmpty ? 1 : (Int(numStr) ?? 1)

            // Merge with existing element if present
            if let idx = result.firstIndex(where: { $0.0 == element }) {
                result[idx].1 += count
            } else {
                result.append((element, count))
            }
        }

        return result
    }

    // ── Linear Algebra ───────────────────────────────

    /// Find the null space of the matrix using Gaussian elimination.
    /// Returns integer coefficients or nil if no solution.
    private static func solveNullSpace(matrix: [[Double]], cols: Int) -> [Int]? {
        var m = matrix
        let rows = m.count

        // Forward elimination
        var pivotRow = 0
        var pivotCols: [Int] = []

        for col in 0..<cols {
            // Find pivot
            var maxRow = pivotRow
            var maxVal = abs(m[pivotRow < rows ? pivotRow : 0][col])
            for row in pivotRow..<rows {
                if abs(m[row][col]) > maxVal {
                    maxVal = abs(m[row][col])
                    maxRow = row
                }
            }

            if maxVal < 1e-10 { continue }

            // Swap rows
            if maxRow != pivotRow {
                m.swapAt(pivotRow, maxRow)
            }

            // Scale pivot row
            let scale = m[pivotRow][col]
            for j in 0...cols {
                m[pivotRow][j] /= scale
            }

            // Eliminate column
            for row in 0..<rows {
                if row == pivotRow { continue }
                let factor = m[row][col]
                if abs(factor) < 1e-10 { continue }
                for j in 0...cols {
                    m[row][j] -= factor * m[pivotRow][j]
                }
            }

            pivotCols.append(col)
            pivotRow += 1
            if pivotRow >= rows { break }
        }

        // Find free variable (column not in pivotCols)
        var freeCol = -1
        for col in 0..<cols {
            if !pivotCols.contains(col) {
                freeCol = col
                break
            }
        }

        // Build solution
        var solution = [Double](repeating: 0, count: cols)

        if freeCol >= 0 {
            // Set free variable to 1, solve for others
            solution[freeCol] = 1.0
            for (i, pc) in pivotCols.enumerated() {
                solution[pc] = -m[i][freeCol]
            }
        } else {
            // Over-determined: set last variable to 1
            let lastCol = cols - 1
            solution[lastCol] = 1.0
            for (i, pc) in pivotCols.enumerated() {
                if i < rows {
                    solution[pc] = -m[i][lastCol]
                }
            }
        }

        // Make all positive
        let minVal = solution.min() ?? 0
        if minVal < 0 {
            for i in 0..<solution.count {
                solution[i] = -solution[i]
            }
        }

        // Ensure all positive
        for i in 0..<solution.count {
            if solution[i] < 1e-10 { solution[i] = abs(solution[i]) }
            if solution[i] < 1e-10 { solution[i] = 1.0 }
        }

        // Scale to integers
        return toIntegers(solution)
    }

    /// Convert floating-point coefficients to smallest integers
    private static func toIntegers(_ values: [Double]) -> [Int]? {
        // Try multiplying by 1..100 to find integer solution
        for multiplier in 1...100 {
            let scaled = values.map { $0 * Double(multiplier) }
            let rounded = scaled.map { Int(round($0)) }
            let isInteger = zip(scaled, rounded).allSatisfy { abs($0 - Double($1)) < 0.01 }
            let allPositive = rounded.allSatisfy { $0 > 0 }

            if isInteger && allPositive {
                // Divide by GCD
                var g = rounded[0]
                for v in rounded.dropFirst() {
                    g = gcd(g, v)
                }
                return rounded.map { $0 / g }
            }
        }
        return values.map { max(1, Int(round($0))) }
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var (a, b) = (abs(a), abs(b))
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }
}
