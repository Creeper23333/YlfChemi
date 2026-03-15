import Vapor

/// Configure all routes for the application
func configureRoutes(_ app: Application) throws {

    // ── Health check ────────────────────────────
    app.get("api", "ping") { req -> [String: String] in
        return ["status": "ok"]
    }

    // ── Formula Builder (new: element+count pairs) ──
    app.post("api", "formula") { req -> Response in
        let input = try req.content.decode(FormulaBuildRequest.self)
        let result = FormulaBuilder.build(elements: input.elements)
        let display = FormulaBuilder.toSubscript(result.formula)
        let response = FormulaBuildResponse(
            formula: result.formula,
            latex: result.latex,
            markdown: result.markdown,
            katex: result.katex,
            display: display
        )
        let body = try JSONEncoder().encode(response)
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: body)
        )
    }

    // ── Legacy formula (valence cross method) ───
    app.post("api", "formula", "cross") { req -> Response in
        let input = try req.content.decode(FormulaRequest.self)
        let result = FormulaGenerator.generate(elements: input.elements)
        let body = try JSONEncoder().encode(result)
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: body)
        )
    }

    // ── Equation balancing ──────────────────────
    app.post("api", "balance") { req -> Response in
        let input = try req.content.decode(BalanceRequest.self)
        let result = EquationBalancer.balance(equation: input.equation)
        let latex = LatexFormatter.equationToLatex(result.balanced)
        let response = BalanceResponse(
            balanced: result.balanced,
            latex: "$$\(latex)$$",
            markdown: "$\(latex)$",
            katex: "$$\(latex)$$"
        )
        let body = try JSONEncoder().encode(response)
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: body)
        )
    }

    // ── Reaction prediction ─────────────────────
    app.post("api", "predict") { req -> Response in
        let input = try req.content.decode(PredictRequest.self)
        let suggestions = ReactionPredictor.predict(reactants: input.reactants)
        let response = PredictResponse(suggestions: suggestions)
        let body = try JSONEncoder().encode(response)
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: body)
        )
    }

    // ── Organic molecule search (by name) ───────
    app.get("api", "organic") { req -> Response in
        // Support both ?name= and ?formula= query params
        if let name = req.query[String.self, at: "name"] {
            guard let molecule = OrganicDatabase.search(name: name) else {
                throw Abort(.notFound, reason: "Molecule '\(name)' not found")
            }
            let body = try JSONEncoder().encode(molecule)
            return Response(
                status: .ok,
                headers: ["Content-Type": "application/json"],
                body: .init(data: body)
            )
        }

        if let formula = req.query[String.self, at: "formula"] {
            guard let molecule = OrganicDatabase.searchByFormula(formula: formula) else {
                throw Abort(.notFound, reason: "No molecule with formula '\(formula)'")
            }
            let body = try JSONEncoder().encode(molecule)
            return Response(
                status: .ok,
                headers: ["Content-Type": "application/json"],
                body: .init(data: body)
            )
        }

        throw Abort(.badRequest, reason: "Provide 'name' or 'formula' query parameter")
    }

    // ── List all organic molecules ──────────────
    app.get("api", "organic", "list") { req -> Response in
        let list = OrganicDatabase.allMolecules()
        let body = try JSONEncoder().encode(list)
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: body)
        )
    }
}
