import Foundation

/// Database of common elements with their valences
struct Element {
    let symbol: String
    let name: String
    let valence: [Int]  // Common valences (positive first for metals)
    let isMetal: Bool
}

struct ElementDB {
    /// Lookup table: symbol -> Element
    static let elements: [String: Element] = {
        var db: [String: Element] = [:]
        for el in allElements {
            db[el.symbol] = el
        }
        return db
    }()

    static func lookup(_ symbol: String) -> Element? {
        return elements[symbol]
    }

    // ── Common elements ──────────────────────────────
    static let allElements: [Element] = [
        // Alkali metals
        Element(symbol: "H",  name: "Hydrogen",   valence: [1],    isMetal: false),
        Element(symbol: "Li", name: "Lithium",     valence: [1],    isMetal: true),
        Element(symbol: "Na", name: "Sodium",      valence: [1],    isMetal: true),
        Element(symbol: "K",  name: "Potassium",   valence: [1],    isMetal: true),

        // Alkaline earth metals
        Element(symbol: "Be", name: "Beryllium",   valence: [2],    isMetal: true),
        Element(symbol: "Mg", name: "Magnesium",   valence: [2],    isMetal: true),
        Element(symbol: "Ca", name: "Calcium",     valence: [2],    isMetal: true),
        Element(symbol: "Ba", name: "Barium",      valence: [2],    isMetal: true),

        // Transition metals
        Element(symbol: "Fe", name: "Iron",        valence: [2, 3], isMetal: true),
        Element(symbol: "Cu", name: "Copper",      valence: [1, 2], isMetal: true),
        Element(symbol: "Zn", name: "Zinc",        valence: [2],    isMetal: true),
        Element(symbol: "Al", name: "Aluminum",    valence: [3],    isMetal: true),
        Element(symbol: "Ag", name: "Silver",      valence: [1],    isMetal: true),
        Element(symbol: "Mn", name: "Manganese",   valence: [2, 4, 7], isMetal: true),
        Element(symbol: "Cr", name: "Chromium",    valence: [2, 3, 6], isMetal: true),
        Element(symbol: "Pb", name: "Lead",        valence: [2, 4], isMetal: true),
        Element(symbol: "Sn", name: "Tin",         valence: [2, 4], isMetal: true),

        // Non-metals
        Element(symbol: "O",  name: "Oxygen",      valence: [2],    isMetal: false),
        Element(symbol: "S",  name: "Sulfur",      valence: [2, 4, 6], isMetal: false),
        Element(symbol: "N",  name: "Nitrogen",    valence: [3, 5], isMetal: false),
        Element(symbol: "P",  name: "Phosphorus",  valence: [3, 5], isMetal: false),
        Element(symbol: "C",  name: "Carbon",      valence: [4],    isMetal: false),
        Element(symbol: "Cl", name: "Chlorine",    valence: [1],    isMetal: false),
        Element(symbol: "Br", name: "Bromine",     valence: [1],    isMetal: false),
        Element(symbol: "I",  name: "Iodine",      valence: [1],    isMetal: false),
        Element(symbol: "F",  name: "Fluorine",    valence: [1],    isMetal: false),
        Element(symbol: "Si", name: "Silicon",     valence: [4],    isMetal: false),
    ]
}
