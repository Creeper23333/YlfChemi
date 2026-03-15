import Vapor

/// Configure all routes for the application
func configureRoutes(_ app: Application) throws {

    // ── Health check ────────────────────────────
    app.get("api", "ping") { req -> [String: String] in
        return ["status": "ok"]
    }

    // ── ChemiGenerator (single endpoint) ────────
    app.post("api", "generate") { req -> Response in
        let input = try req.content.decode(GenerateRequest.self)
        let lang = input.language ?? "en"

        do {
            let result = try await AIAssistant.query(input: input.input, language: lang)
            let response = GenerateResponse(
                name: result.name,
                formula: result.formula,
                latex: result.latex,
                structural_latex: result.structural_latex,
                markdown: result.markdown,
                smiles: result.smiles,
                reaction: result.reaction,
                products: result.products,
                explanation: result.explanation,
                type: result.type,
                error_message: result.error_message,
                error: nil
            )
            let body = try JSONEncoder().encode(response)
            return Response(
                status: .ok,
                headers: ["Content-Type": "application/json"],
                body: .init(data: body)
            )
        } catch {
            let response = GenerateResponse(
                name: nil, formula: nil, latex: nil, structural_latex: nil,
                markdown: nil, smiles: nil, reaction: nil, products: nil,
                explanation: nil, type: "error", error_message: nil,
                error: "Generation failed: \(error)"
            )
            let body = try JSONEncoder().encode(response)
            return Response(
                status: .ok,
                headers: ["Content-Type": "application/json"],
                body: .init(data: body)
            )
        }
    }
}
