import Foundation

/// Database of common organic molecules with name, formula, and SMILES notation
struct OrganicMolecule: Codable {
    let name: String
    let formula: String
    let smiles: String
}

struct OrganicDatabase {

    static let molecules: [OrganicMolecule] = [
        OrganicMolecule(name: "benzene",      formula: "C6H6",      smiles: "c1ccccc1"),
        OrganicMolecule(name: "toluene",       formula: "C7H8",      smiles: "Cc1ccccc1"),
        OrganicMolecule(name: "phenol",        formula: "C6H6O",     smiles: "Oc1ccccc1"),
        OrganicMolecule(name: "ethanol",       formula: "C2H6O",     smiles: "CCO"),
        OrganicMolecule(name: "acetone",       formula: "C3H6O",     smiles: "CC(=O)C"),
        OrganicMolecule(name: "acetic acid",   formula: "C2H4O2",    smiles: "CC(=O)O"),
        OrganicMolecule(name: "aniline",       formula: "C6H7N",     smiles: "Nc1ccccc1"),
        OrganicMolecule(name: "methane",       formula: "CH4",       smiles: "C"),
        OrganicMolecule(name: "ethylene",      formula: "C2H4",      smiles: "C=C"),
        OrganicMolecule(name: "acetylene",     formula: "C2H2",      smiles: "C#C"),
        OrganicMolecule(name: "methanol",      formula: "CH4O",      smiles: "CO"),
        OrganicMolecule(name: "formaldehyde",  formula: "CH2O",      smiles: "C=O"),
        OrganicMolecule(name: "glycine",       formula: "C2H5NO2",   smiles: "NCC(=O)O"),
        OrganicMolecule(name: "naphthalene",   formula: "C10H8",     smiles: "c1ccc2ccccc2c1"),
        OrganicMolecule(name: "cyclohexane",   formula: "C6H12",     smiles: "C1CCCCC1"),
    ]

    /// Search by name (case-insensitive, partial match)
    static func search(name: String) -> OrganicMolecule? {
        let query = name.lowercased().trimmingCharacters(in: .whitespaces)
        return molecules.first(where: { $0.name.lowercased() == query }) ??
               molecules.first(where: { $0.name.lowercased().contains(query) })
    }

    /// Search by formula (case-insensitive exact match)
    static func searchByFormula(formula: String) -> OrganicMolecule? {
        let query = formula.trimmingCharacters(in: .whitespaces)
        return molecules.first(where: {
            $0.formula.lowercased() == query.lowercased()
        })
    }

    /// Return all molecules
    static func allMolecules() -> [OrganicMolecule] {
        return molecules
    }
}
