// ============================================
// YlfChemi — ChemiGenerator Frontend
// ============================================

// ── Subscript helper (fixed for multi-digit numbers like 10, 12) ──
const SUB = { '0':'\u2080','1':'\u2081','2':'\u2082','3':'\u2083','4':'\u2084',
              '5':'\u2085','6':'\u2086','7':'\u2087','8':'\u2088','9':'\u2089' };

function toSubscript(text) {
    if (!text) return '';
    // Match element symbols followed by digits, convert ALL digits to subscript
    return text.replace(/([A-Za-z\)])(\d+)/g, (match, prefix, digits) => {
        return prefix + digits.split('').map(d => SUB[d] || d).join('');
    });
}

// ── Copy to clipboard ───────────────────────
function copyText(id) {
    const el = document.getElementById(id);
    const text = el.textContent || el.innerText;
    navigator.clipboard.writeText(text).then(() => {
        const btn = el.parentElement.querySelector('.btn-copy');
        if (btn) { const orig = btn.textContent; btn.textContent = '✓'; setTimeout(() => btn.textContent = orig, 800); }
    });
}

// ── SmilesDrawer init ───────────────────────
let smilesDrawer = null;
try {
    smilesDrawer = new SmilesDrawer.Drawer({
        width: 500, height: 400,
        bondThickness: 1.5, bondLength: 30,
        shortBondLength: 0.85,
        fontSizeLarge: 11, fontSizeSmall: 7,
        padding: 30,
        themes: {
            dark: {
                C: '#1a1a1a', O: '#c0392b', N: '#2980b9',
                S: '#f39c12', H: '#555555', BACKGROUND: '#ffffff'
            }
        }
    });
} catch (e) { console.warn('SmilesDrawer not available:', e); }

// ── Enter key binding ───────────────────────
document.getElementById('gen-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') generate();
});

// ── Helper: show/hide output row ────────────
function setField(rowId, valueId, value) {
    const row = document.getElementById(rowId);
    const el = document.getElementById(valueId);
    if (value) {
        row.style.display = '';
        el.textContent = value;
    } else {
        row.style.display = 'none';
    }
}

// ── Render SMILES structure ─────────────────
function renderSmiles(smiles) {
    const canvas = document.getElementById('smiles-canvas');
    const box = document.getElementById('structure-box');
    if (!smiles || !smilesDrawer) {
        box.classList.add('hidden');
        return;
    }
    box.classList.remove('hidden');
    SmilesDrawer.parse(smiles, tree => smilesDrawer.draw(tree, canvas, 'dark'),
        err => { console.error('SMILES parse error:', err); box.classList.add('hidden'); });
}

// ════════════════════════════════════════════
// MAIN GENERATE FUNCTION
// ════════════════════════════════════════════

async function generate() {
    const input = document.getElementById('gen-input').value.trim();
    if (!input) return;

    const loading = document.getElementById('gen-loading');
    const output = document.getElementById('gen-output');
    const errorDiv = document.getElementById('gen-error');
    const btn = document.getElementById('gen-btn');

    // Show loading state
    loading.classList.remove('hidden');
    output.classList.add('hidden');
    errorDiv.classList.add('hidden');
    btn.disabled = true;
    btn.textContent = 'Generating...';

    try {
        const res = await fetch('/api/generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ input })
        });
        const data = await res.json();

        loading.classList.add('hidden');
        btn.disabled = false;
        btn.textContent = 'Generate';

        // System-level error
        if (data.error) {
            errorDiv.classList.remove('hidden');
            errorDiv.textContent = data.error;
            return;
        }

        // Content-level error (non-chemistry input)
        if (data.type === 'error') {
            errorDiv.classList.remove('hidden');
            errorDiv.textContent = data.error_message || 'This does not appear to be a chemistry-related query.';
            return;
        }

        output.classList.remove('hidden');

        // Populate fields
        setField('row-name', 'out-name', data.name);
        setField('row-formula', 'out-formula', data.formula ? toSubscript(data.formula) : null);

        // Type display
        const typeLabels = {
            'organic': 'Organic Compound',
            'inorganic': 'Inorganic Compound',
            'reaction': 'Chemical Reaction'
        };
        setField('row-type', 'out-type', typeLabels[data.type] || data.type);

        setField('row-latex', 'out-latex', data.latex);
        setField('row-markdown', 'out-markdown', data.markdown);
        setField('row-reaction', 'out-reaction', data.reaction ? toSubscript(data.reaction) : null);
        setField('row-products', 'out-products',
            data.products && data.products.length > 0 ? data.products.map(toSubscript).join(', ') : null);
        setField('row-smiles', 'out-smiles', data.smiles);
        setField('row-explanation', 'out-explanation', data.explanation);

        // Render KaTeX
        const katexRow = document.getElementById('row-rendered');
        const katexEl = document.getElementById('out-katex-render');
        const latexSrc = data.latex || data.markdown;
        if (latexSrc) {
            katexRow.style.display = '';
            try {
                const inner = latexSrc.replace(/^\$+/, '').replace(/\$+$/, '');
                katex.render(inner, katexEl, { throwOnError: false, displayMode: false });
            } catch(e) { katexEl.textContent = latexSrc; }
        } else {
            katexRow.style.display = 'none';
        }

        // Render SMILES structure for organic compounds
        if (data.type === 'organic' && data.smiles) {
            renderSmiles(data.smiles);
        } else {
            document.getElementById('structure-box').classList.add('hidden');
        }

    } catch (err) {
        loading.classList.add('hidden');
        btn.disabled = false;
        btn.textContent = 'Generate';
        errorDiv.classList.remove('hidden');
        errorDiv.textContent = 'Request failed: ' + err.message;
    }
}

// ── Init ────────────────────────────────────
async function init() {
    try {
        const res = await fetch('/api/ping');
        const data = await res.json();
        if (data.status === 'ok') console.log('YlfChemi server connected');
    } catch (err) { console.warn('Server not reachable:', err); }
}
init();
