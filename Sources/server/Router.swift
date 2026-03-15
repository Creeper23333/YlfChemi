import Vapor

/// Configure all routes for the application
func configureRoutes(_ app: Application) throws {
    // Health check
    app.get("api", "ping") { req -> [String: String] in
        return ["status": "ok"]
    }

    // Formula generation
    app.post("api", "formula") { req -> Response in
        let input = try req.content.decode(FormulaRequest.self)
        let result = FormulaGenerator.generate(elements: input.elements)
        let body = try JSONEncoder().encode(result)
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: body)
        )
    }

    // Equation balancing
    app.post("api", "balance") { req -> Response in
        let input = try req.content.decode(BalanceRequest.self)
        let result = EquationBalancer.balance(equation: input.equation)
        let body = try JSONEncoder().encode(result)
        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: body)
        )
    }

    // Organic molecule search
    app.get("api", "organic") { req -> Response in
        guard let name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest, reason: "Missing 'name' query parameter")
        }
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

    // List all organic molecules
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
