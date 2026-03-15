import Vapor
import Foundation

// ============================================
// ChemLazy — Lazy Chemistry Toolkit
// ============================================
// Local Swift server + WebUI frontend
// Starts on localhost:5173, opens browser automatically.

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = try await Application.make(env)

// Configure port
app.http.server.configuration.port = 5173
app.http.server.configuration.hostname = "127.0.0.1"

// Serve static files from web/ directory
let webDir = findWebDirectory()
print("📂 Serving static files from: \(webDir)")
app.middleware.use(FileMiddleware(publicDirectory: webDir, defaultFile: "index.html"))

// Register API routes
try configureRoutes(app)

// Open browser after a short delay
Task {
    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
    BrowserLauncher.open(url: "http://localhost:5173")
}

print("🧪 ChemLazy server starting on http://localhost:5173")
try await app.execute()
try await app.asyncShutdown()

/// Find the web/ directory — tries multiple strategies
func findWebDirectory() -> String {
    // Strategy 1: Resolve the real path of the executable
    let execPath = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
    let execDir = URL(fileURLWithPath: execPath).deletingLastPathComponent().path

    // Strategy 2: Current working directory
    let cwd = FileManager.default.currentDirectoryPath

    let candidates = [
        // From CWD (most common when running `swift run` from project root)
        cwd + "/web",
        // From executable location (.build/debug/ChemLazy -> ../../web)
        execDir + "/../../web",
        execDir + "/../../../web",
        execDir + "/../web",
        execDir + "/web",
    ]

    for candidate in candidates {
        // Standardize the path to resolve ../ components
        let standardized = URL(fileURLWithPath: candidate).standardized.path
        let indexPath = standardized + "/index.html"
        if FileManager.default.fileExists(atPath: indexPath) {
            // FileMiddleware needs trailing slash
            return standardized + "/"
        }
    }

    // Fallback
    print("⚠️  Could not find web/ directory, tried: \(candidates)")
    return cwd + "/web/"
}
