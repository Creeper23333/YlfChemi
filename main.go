package main

import (
	"bytes"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os/exec"
	"regexp"
	"runtime"
	"strings"
	"time"
)

//go:embed web/*
var webFS embed.FS

// ── Config ──────────────────────────────────
const (
	listenAddr = "127.0.0.1:5173"
	apiURL     = "https://api.siliconflow.cn/v1/chat/completions"
	apiKey     = "sk-rxdkwdcxdnzunjjjcczkpzgaybzyunbehakjshmlehlyoain"
	model      = "deepseek-ai/DeepSeek-V3.1-Terminus"
)

// ── System Prompt ───────────────────────────
const systemPrompt = `Chemistry generator. Return ONLY valid JSON with these fields:
name(string|null), formula(string|null), latex(string|null), structural_latex(string|null), markdown(string|null), smiles(string|null), reaction(string|null), products(string[]|[]), explanation(string|null), type("organic"|"inorganic"|"reaction"|"error"), error_message(string|null).

Rules: Non-chemistry input→type="error". Organic→MUST include valid SMILES and structural_latex. latex=molecular formula LaTeX. structural_latex=structural formula in LaTeX using \\ce{} or chemfig-style notation showing bonds (e.g. C_6H_5COOH for benzoic acid). For inorganic, structural_latex=null. Multi-digit subscripts use braces: C_{10}. No code fences. No comments.

Example: {"name":"benzene","formula":"C6H6","latex":"\\mathrm{C_6H_6}","structural_latex":"\\ce{C6H6}","markdown":"$C_6H_6$","smiles":"c1ccccc1","reaction":null,"products":[],"explanation":"Aromatic hydrocarbon.","type":"organic","error_message":null}`

// ── Request/Response types ──────────────────

type GenerateRequest struct {
	Input    string `json:"input"`
	Language string `json:"language,omitempty"`
}

type GenerateResponse struct {
	Name            *string  `json:"name"`
	Formula         *string  `json:"formula"`
	Latex           *string  `json:"latex"`
	StructuralLatex *string  `json:"structural_latex"`
	Markdown        *string  `json:"markdown"`
	Smiles          *string  `json:"smiles"`
	Reaction        *string  `json:"reaction"`
	Products        []string `json:"products"`
	Explanation     *string  `json:"explanation"`
	Type            *string  `json:"type"`
	ErrorMessage    *string  `json:"error_message"`
	Error           *string  `json:"error,omitempty"`
}

// ── Main ────────────────────────────────────

func main() {
	// Serve embedded web files
	webSub, err := fs.Sub(webFS, "web")
	if err != nil {
		panic(err)
	}
	fileServer := http.FileServer(http.FS(webSub))

	mux := http.NewServeMux()

	// API routes
	mux.HandleFunc("/api/ping", handlePing)
	mux.HandleFunc("/api/generate", handleGenerate)

	// Static files (fallback to index.html for SPA)
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Try to serve the file; if not found, serve index.html
		path := r.URL.Path
		if path == "/" {
			path = "/index.html"
		}
		// Check if file exists in embedded FS
		f, err := webSub.(fs.ReadFileFS).ReadFile(strings.TrimPrefix(path, "/"))
		if err != nil {
			// Serve index.html as fallback
			f, _ = webSub.(fs.ReadFileFS).ReadFile("index.html")
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.Write(f)
			return
		}
		_ = f
		fileServer.ServeHTTP(w, r)
	})

	// Auto-open browser after short delay
	go func() {
		time.Sleep(500 * time.Millisecond)
		openBrowser("http://" + listenAddr)
	}()

	fmt.Printf("🧪 YlfChemi server starting on http://%s\n", listenAddr)
	if err := http.ListenAndServe(listenAddr, mux); err != nil {
		fmt.Printf("Server error: %v\n", err)
	}
}

// ── Handlers ────────────────────────────────

func handlePing(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok"}`))
}

func handleGenerate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req GenerateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "Invalid request: "+err.Error())
		return
	}

	lang := req.Language
	if lang == "" {
		lang = "en"
	}

	result, err := queryAI(req.Input, lang)
	if err != nil {
		writeError(w, "Generation failed: "+err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func writeError(w http.ResponseWriter, msg string) {
	errType := "error"
	resp := GenerateResponse{Type: &errType, Error: &msg}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// ── AI Proxy ────────────────────────────────

func queryAI(input, language string) (*GenerateResponse, error) {
	langInstruction := "\n\nIMPORTANT: The 'explanation' and 'name' fields MUST be written in English."
	if language == "cn" {
		langInstruction = "\n\nIMPORTANT: The 'explanation' and 'name' fields MUST be written in Chinese (简体中文). The 'error_message' field must also be in Chinese."
	}

	fullPrompt := systemPrompt + langInstruction

	body := map[string]interface{}{
		"model": model,
		"messages": []map[string]string{
			{"role": "system", "content": fullPrompt},
			{"role": "user", "content": input},
		},
		"temperature":     0.2,
		"max_tokens":      1024,
		"enable_thinking": false,
	}

	bodyJSON, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("marshal error: %w", err)
	}

	httpReq, err := http.NewRequest("POST", apiURL, bytes.NewReader(bodyJSON))
	if err != nil {
		return nil, fmt.Errorf("request error: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+apiKey)

	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("API request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response failed: %w", err)
	}

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("API error (%d): %s", resp.StatusCode, string(respBody))
	}

	// Parse API response to extract content
	var apiResp struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(respBody, &apiResp); err != nil {
		return nil, fmt.Errorf("parse API response failed: %w", err)
	}
	if len(apiResp.Choices) == 0 {
		return nil, fmt.Errorf("no choices in API response")
	}

	content := apiResp.Choices[0].Message.Content
	cleaned := extractJSON(content)

	var result GenerateResponse
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return nil, fmt.Errorf("parse chemistry JSON failed: %w\nRaw: %s", err, cleaned)
	}

	return &result, nil
}

// ── JSON Extraction ─────────────────────────

func extractJSON(text string) string {
	cleaned := strings.TrimSpace(text)

	// Remove markdown code fences
	if strings.HasPrefix(cleaned, "```json") {
		cleaned = cleaned[7:]
	} else if strings.HasPrefix(cleaned, "```") {
		cleaned = cleaned[3:]
	}
	if strings.HasSuffix(cleaned, "```") {
		cleaned = cleaned[:len(cleaned)-3]
	}
	cleaned = strings.TrimSpace(cleaned)

	// Find JSON object boundaries
	start := strings.Index(cleaned, "{")
	end := strings.LastIndex(cleaned, "}")
	if start >= 0 && end > start {
		cleaned = cleaned[start : end+1]
	}

	// Remove single-line comments (// ...) outside strings
	lines := strings.Split(cleaned, "\n")
	for i, line := range lines {
		lines[i] = removeLineComments(line)
	}
	cleaned = strings.Join(lines, "\n")

	// Remove trailing commas before } or ]
	re := regexp.MustCompile(`,\s*([}\]])`)
	cleaned = re.ReplaceAllString(cleaned, "$1")

	return strings.TrimSpace(cleaned)
}

func removeLineComments(line string) string {
	inString := false
	escaped := false
	for i, ch := range line {
		if escaped {
			escaped = false
			continue
		}
		if ch == '\\' && inString {
			escaped = true
			continue
		}
		if ch == '"' {
			inString = !inString
			continue
		}
		if !inString && ch == '/' && i+1 < len(line) && line[i+1] == '/' {
			return line[:i]
		}
	}
	return line
}

// ── Browser Launcher ────────────────────────

func openBrowser(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", url)
	case "linux":
		cmd = exec.Command("xdg-open", url)
	case "windows":
		cmd = exec.Command("cmd", "/c", "start", url)
	default:
		fmt.Printf("Open %s in your browser\n", url)
		return
	}
	cmd.Run()
}
