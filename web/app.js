// ============================================
// ChemLazy v2 — Frontend Application
// ============================================

// ── Tab Navigation ──────────────────────────
document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById('tab-' + tab.dataset.tab).classList.add('active');
    });
});

// ── Subscript helper ────────────────────────
const SUB = { '0':'\u2080','1':'\u2081','2':'\u2082','3':'\u2083','4':'\u2084',
              '5':'\u2085','6':'\u2086','7':'\u2087','8':'\u2088','9':'\u2089' };

function toSubscript(text) {
    let r = '', prev = false;
    for (const ch of text) {
        if (/[0-9]/.test(ch) && prev) r += SUB[ch] || ch;
        else r += ch;
        prev = /[A-Za-z]/.test(ch);
    }
    return r;
}

// ── Copy to clipboard ───────────────────────
function copyText(id) {
    const el = document.getElementById(id);
    const text = el.textContent || el.innerText;
    navigator.clipboard.writeText(text).then(() => {
        // Brief visual feedback
        const btn = el.parentElement.querySelector('.btn-copy');
        if (btn) { const orig = btn.textContent; btn.textContent = '✓'; setTimeout(() => btn.textContent = orig, 800); }
    });
}

// ════════════════════════════════════════════
// FORMULA BUILDER
// ════════════════════════════════════════════

let elementRows = [];

function addElement(symbol, count) {
    const list = document.getElementById('element-list');
    const idx = elementRows.length;
    const row = document.createElement('div');
    row.className = 'element-row';
    row.innerHTML =
        '<span class="el-label">Element</span>' +
        '<input type="text" class="el-symbol" placeholder="C" maxlength="3" value="' + (symbol||'') + '" oninput="updatePreview()">' +
        '<span class="el-label">Count</span>' +
        '<input type="number" class="el-count" placeholder="1" min="1" value="' + (count||1) + '" oninput="updatePreview()">' +
        '<button class="btn-remove" onclick="removeElement(this)">×</button>';
    list.appendChild(row);
    elementRows.push(row);
    updatePreview();
}

function removeElement(btn) {
    const row = btn.parentElement;
    row.remove();
    elementRows = elementRows.filter(r => r !== row);
    updatePreview();
}

function getElements() {
    const rows = document.querySelectorAll('#element-list .element-row');
    const elements = [];
    rows.forEach(row => {
        const sym = row.querySelector('.el-symbol').value.trim();
        const cnt = parseInt(row.querySelector('.el-count').value) || 1;
        if (sym) elements.push({ symbol: sym, count: cnt });
    });
    return elements;
}

function updatePreview() {
    const elements = getElements();
    let preview = '';
    elements.forEach(el => {
        preview += el.symbol;
        if (el.count > 1) preview += el.count;
    });
    document.getElementById('formula-preview').textContent = preview ? toSubscript(preview) : '—';
}

async function buildFormula() {
    const elements = getElements();
    if (elements.length === 0) return;

    try {
        const res = await fetch('/api/formula', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ elements })
        });
        const data = await res.json();
        const panel = document.getElementById('formula-output');
        panel.classList.remove('hidden');

        document.getElementById('out-display').textContent = data.display || toSubscript(data.formula);
        document.getElementById('out-latex').textContent = data.latex;
        document.getElementById('out-markdown').textContent = data.markdown;
        document.getElementById('out-katex-raw').textContent = data.katex;

        // Render KaTeX
        const katexEl = document.getElementById('out-katex-render');
        try {
            const inner = data.katex.replace(/^\$\$/, '').replace(/\$\$$/, '');
            katex.render(inner, katexEl, { throwOnError: false, displayMode: false });
        } catch(e) { katexEl.textContent = data.katex; }

        // Try to detect organic molecule
        tryDetectOrganic(data.formula);
    } catch (err) {
        console.error('Formula build error:', err);
    }
}

async function tryDetectOrganic(formula) {
    const box = document.getElementById('organic-detect');
    try {
        const res = await fetch('/api/organic?formula=' + encodeURIComponent(formula));
        if (res.ok) {
            const mol = await res.json();
            box.classList.remove('hidden');
            document.getElementById('detect-name').textContent = mol.name;
            document.getElementById('detect-smiles').textContent = 'SMILES: ' + mol.smiles;
        } else {
            box.classList.add('hidden');
        }
    } catch(e) { box.classList.add('hidden'); }
}

// Init with two empty element rows
addElement('', 1);
addElement('', 1);

// ════════════════════════════════════════════
// REACTION BUILDER
// ════════════════════════════════════════════

function addReactant(value) {
    addCompound('reactant-list', value || '');
}

function addProduct(value) {
    addCompound('product-list', value || '');
}

function addCompound(listId, value) {
    const list = document.getElementById(listId);
    const row = document.createElement('div');
    row.className = 'compound-row';
    row.innerHTML =
        '<input type="text" placeholder="e.g. Fe" value="' + value + '" spellcheck="false">' +
        '<button class="btn-remove" onclick="this.parentElement.remove()">×</button>';
    list.appendChild(row);
}

function getCompounds(listId) {
    const inputs = document.querySelectorAll('#' + listId + ' .compound-row input');
    return Array.from(inputs).map(i => i.value.trim()).filter(v => v);
}

async function suggestProducts() {
    const reactants = getCompounds('reactant-list');
    if (reactants.length === 0) return;

    try {
        const res = await fetch('/api/predict', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ reactants })
        });
        const data = await res.json();
        const panel = document.getElementById('suggestions-panel');
        const list = document.getElementById('suggestions-list');

        if (data.suggestions && data.suggestions.length > 0) {
            panel.classList.remove('hidden');
            list.innerHTML = '';
            data.suggestions.forEach(s => {
                s.products.forEach(p => {
                    const chip = document.createElement('span');
                    chip.className = 'suggestion-chip';
                    chip.textContent = toSubscript(p);
                    chip.dataset.value = p;
                    chip.onclick = () => addProduct(p);
                    list.appendChild(chip);
                });
                // Also show full equation
                const eq = document.createElement('div');
                eq.style.cssText = 'font-size:12px;color:#888;margin:4px 0;';
                eq.textContent = toSubscript(s.equation);
                list.appendChild(eq);
            });
        } else {
            panel.classList.remove('hidden');
            list.innerHTML = '<span style="color:#888;font-size:12px">No suggestions found</span>';
        }
    } catch (err) {
        console.error('Predict error:', err);
    }
}

async function balanceReaction() {
    const reactants = getCompounds('reactant-list');
    const products = getCompounds('product-list');
    if (reactants.length === 0 || products.length === 0) return;

    const equation = reactants.join(' + ') + ' -> ' + products.join(' + ');
    await doBalance(equation);
}

async function balanceFromInput() {
    const input = document.getElementById('balance-input').value.trim();
    if (!input) return;
    await doBalance(input);
}

document.getElementById('balance-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') balanceFromInput();
});

async function doBalance(equation) {
    try {
        const res = await fetch('/api/balance', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ equation })
        });
        const data = await res.json();
        const panel = document.getElementById('reaction-output');
        panel.classList.remove('hidden');

        document.getElementById('rxn-balanced').textContent = toSubscript(data.balanced);
        document.getElementById('rxn-latex').textContent = data.latex;
        document.getElementById('rxn-markdown').textContent = data.markdown;
        document.getElementById('rxn-katex-raw').textContent = data.katex;

        // Render KaTeX
        const katexEl = document.getElementById('rxn-katex-render');
        try {
            const inner = data.katex.replace(/^\$\$/, '').replace(/\$\$$/, '');
            katex.render(inner, katexEl, { throwOnError: false, displayMode: false });
        } catch(e) { katexEl.textContent = data.katex; }
    } catch (err) {
        console.error('Balance error:', err);
    }
}

// Init with one reactant row
addReactant('');
addReactant('');

// ════════════════════════════════════════════
// ORGANIC VIEWER
// ════════════════════════════════════════════

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

document.getElementById('organic-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') searchOrganic();
});

async function searchOrganic() {
    const input = document.getElementById('organic-input').value.trim();
    if (!input) return;

    // Try name first, then formula
    let url = '/api/organic?name=' + encodeURIComponent(input);
    let res = await fetch(url);
    if (!res.ok) {
        url = '/api/organic?formula=' + encodeURIComponent(input);
        res = await fetch(url);
    }

    const panel = document.getElementById('organic-result');

    if (!res.ok) {
        panel.classList.remove('hidden');
        document.getElementById('org-name').textContent = 'Not found';
        document.getElementById('org-formula').textContent = '';
        document.getElementById('org-smiles').textContent = '';
        document.getElementById('smiles-canvas').style.display = 'none';
        return;
    }

    const data = await res.json();
    panel.classList.remove('hidden');
    document.getElementById('org-name').textContent = data.name;
    document.getElementById('org-formula').textContent = toSubscript(data.formula);
    document.getElementById('org-smiles').textContent = data.smiles;
    renderSmiles(data.smiles);
}

function renderSmiles(smiles) {
    const canvas = document.getElementById('smiles-canvas');
    canvas.style.display = 'block';
    if (!smilesDrawer) {
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.font = '13px monospace';
        ctx.fillStyle = '#888';
        ctx.fillText('SmilesDrawer not loaded', 20, 30);
        return;
    }
    SmilesDrawer.parse(smiles, tree => smilesDrawer.draw(tree, canvas, 'dark'),
        err => console.error('SMILES parse error:', err));
}

function selectMolecule(name) {
    document.getElementById('organic-input').value = name;
    searchOrganic();
}

// ── Load molecule list ──────────────────────
async function loadMoleculeList() {
    try {
        const res = await fetch('/api/organic/list');
        const list = await res.json();
        const container = document.getElementById('organic-list');
        let html = '<div class="molecule-list-title">Available Molecules</div>';
        list.forEach(mol => {
            html += '<span class="molecule-chip" onclick="selectMolecule(\'' + mol.name + '\')">' + mol.name + '</span>';
        });
        container.innerHTML = html;
    } catch (err) { console.warn('Could not load molecule list:', err); }
}

// ════════════════════════════════════════════
// AI ASSISTANT
// ════════════════════════════════════════════

document.getElementById('ai-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') queryAI();
});

async function queryAI() {
    const input = document.getElementById('ai-input').value.trim();
    if (!input) return;

    const loading = document.getElementById('ai-loading');
    const output = document.getElementById('ai-output');
    const errorDiv = document.getElementById('ai-error');
    const btn = document.getElementById('ai-btn');

    // Show loading state
    loading.classList.remove('hidden');
    output.classList.add('hidden');
    errorDiv.classList.add('hidden');
    btn.disabled = true;
    btn.textContent = 'Thinking...';

    try {
        const res = await fetch('/api/ai', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ input })
        });
        const data = await res.json();

        loading.classList.add('hidden');
        btn.disabled = false;
        btn.textContent = 'Generate';

        if (data.error) {
            errorDiv.classList.remove('hidden');
            errorDiv.textContent = data.error;
            return;
        }

        output.classList.remove('hidden');

        // Populate fields, hide empty ones
        setAIField('ai-row-name', 'ai-name', data.name);
        setAIField('ai-row-formula', 'ai-formula', data.formula ? toSubscript(data.formula) : null);
        setAIField('ai-row-latex', 'ai-latex', data.latex);
        setAIField('ai-row-markdown', 'ai-markdown', data.markdown);
        setAIField('ai-row-reaction', 'ai-reaction', data.reaction ? toSubscript(data.reaction) : null);
        setAIField('ai-row-products', 'ai-products',
            data.products && data.products.length > 0 ? data.products.map(toSubscript).join(', ') : null);
        setAIField('ai-row-explanation', 'ai-explanation', data.explanation);

        // Render KaTeX if latex available
        const katexRow = document.getElementById('ai-row-katex');
        const katexEl = document.getElementById('ai-katex-render');
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

        // Render SMILES structure if available
        const structBox = document.getElementById('ai-structure-box');
        if (data.smiles) {
            structBox.classList.remove('hidden');
            renderAISmiles(data.smiles);
        } else {
            structBox.classList.add('hidden');
        }

    } catch (err) {
        loading.classList.add('hidden');
        btn.disabled = false;
        btn.textContent = 'Generate';
        errorDiv.classList.remove('hidden');
        errorDiv.textContent = 'Request failed: ' + err.message;
    }
}

function setAIField(rowId, valueId, value) {
    const row = document.getElementById(rowId);
    const el = document.getElementById(valueId);
    if (value) {
        row.style.display = '';
        el.textContent = value;
    } else {
        row.style.display = 'none';
    }
}

function renderAISmiles(smiles) {
    const canvas = document.getElementById('ai-smiles-canvas');
    if (!smilesDrawer) return;
    SmilesDrawer.parse(smiles, tree => smilesDrawer.draw(tree, canvas, 'dark'),
        err => console.error('AI SMILES parse error:', err));
}

// ── Init ────────────────────────────────────
async function init() {
    try {
        const res = await fetch('/api/ping');
        const data = await res.json();
        if (data.status === 'ok') console.log('ChemLazy server connected');
    } catch (err) { console.warn('Server not reachable:', err); }
    loadMoleculeList();
}
init();
