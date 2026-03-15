// ============================================
// ChemLazy — Frontend Application
// ============================================

// ── Tab Navigation ──────────────────────────

document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        // Deactivate all tabs
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));

        // Activate clicked tab
        tab.classList.add('active');
        const target = document.getElementById('tab-' + tab.dataset.tab);
        if (target) target.classList.add('active');
    });
});

// ── Keyboard shortcuts ──────────────────────

document.getElementById('formula-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') generateFormula();
});

document.getElementById('balance-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') balanceEquation();
});

document.getElementById('organic-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') searchOrganic();
});

// ── Formula Generator ───────────────────────

async function generateFormula() {
    const input = document.getElementById('formula-input').value.trim();
    const resultBox = document.getElementById('formula-result');

    if (!input) return;

    // Parse "Na + Cl" into ["Na", "Cl"]
    const elements = input.split('+').map(s => s.trim()).filter(s => s.length > 0);

    try {
        const res = await fetch('/api/formula', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ elements })
        });
        const data = await res.json();

        resultBox.classList.remove('hidden');

        if (data.formula && !data.formula.startsWith('Error')) {
            resultBox.innerHTML =
                '<div class="result-label">Result</div>' +
                '<div class="result-formula">' + formatChemical(data.formula) + '</div>';
        } else {
            resultBox.innerHTML =
                '<div class="result-error">' + (data.formula || 'Unknown error') + '</div>';
        }
    } catch (err) {
        resultBox.classList.remove('hidden');
        resultBox.innerHTML = '<div class="result-error">Server error: ' + err.message + '</div>';
    }
}

// ── Equation Balancer ───────────────────────

async function balanceEquation() {
    const input = document.getElementById('balance-input').value.trim();
    const resultBox = document.getElementById('balance-result');

    if (!input) return;

    try {
        const res = await fetch('/api/balance', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ equation: input })
        });
        const data = await res.json();

        resultBox.classList.remove('hidden');

        if (data.balanced && !data.balanced.startsWith('Error')) {
            resultBox.innerHTML =
                '<div class="result-label">Balanced</div>' +
                '<div class="result-formula">' + formatChemical(data.balanced) + '</div>';
        } else {
            resultBox.innerHTML =
                '<div class="result-error">' + (data.balanced || 'Could not balance') + '</div>';
        }
    } catch (err) {
        resultBox.classList.remove('hidden');
        resultBox.innerHTML = '<div class="result-error">Server error: ' + err.message + '</div>';
    }
}

// ── Organic Search ──────────────────────────

// Initialize SmilesDrawer
let smilesDrawer = null;
try {
    smilesDrawer = new SmilesDrawer.Drawer({
        width: 500,
        height: 400,
        bondThickness: 1.5,
        bondLength: 30,
        shortBondLength: 0.85,
        fontSizeLarge: 11,
        fontSizeSmall: 7,
        padding: 30,
        themes: {
            dark: {
                C: '#1a1a1a',
                O: '#c0392b',
                N: '#2980b9',
                S: '#f39c12',
                H: '#555555',
                BACKGROUND: '#ffffff'
            }
        }
    });
} catch (e) {
    console.warn('SmilesDrawer not available:', e);
}

async function searchOrganic() {
    const input = document.getElementById('organic-input').value.trim();
    const resultBox = document.getElementById('organic-result');
    const infoDiv = document.getElementById('organic-info');

    if (!input) return;

    try {
        const res = await fetch('/api/organic?name=' + encodeURIComponent(input));

        if (!res.ok) {
            resultBox.classList.remove('hidden');
            infoDiv.innerHTML = '<div class="result-error">Molecule not found: ' + input + '</div>';
            document.getElementById('smiles-canvas').style.display = 'none';
            return;
        }

        const data = await res.json();
        resultBox.classList.remove('hidden');

        infoDiv.innerHTML =
            '<div class="info-row"><span class="info-label">Name</span><span class="info-value">' + data.name + '</span></div>' +
            '<div class="info-row"><span class="info-label">Formula</span><span class="info-value">' + formatChemical(data.formula) + '</span></div>' +
            '<div class="info-row"><span class="info-label">SMILES</span><span class="info-value">' + data.smiles + '</span></div>';

        // Render structure
        renderSmiles(data.smiles);
    } catch (err) {
        resultBox.classList.remove('hidden');
        infoDiv.innerHTML = '<div class="result-error">Server error: ' + err.message + '</div>';
    }
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

    SmilesDrawer.parse(smiles, function (tree) {
        smilesDrawer.draw(tree, canvas, 'dark');
    }, function (err) {
        console.error('SMILES parse error:', err);
    });
}

// ── Chemical Formula Formatter ──────────────
// Converts "H2SO4" to "H₂SO₄" with proper subscripts

function formatChemical(text) {
    if (!text) return '';

    // Unicode subscript digits
    const subscriptMap = {
        '0': '\u2080', '1': '\u2081', '2': '\u2082', '3': '\u2083',
        '4': '\u2084', '5': '\u2085', '6': '\u2086', '7': '\u2087',
        '8': '\u2088', '9': '\u2089'
    };

    // Replace digits that follow letters (chemical subscripts) with unicode subscripts
    // But preserve digits at the start of a compound (coefficients like "4Fe")
    let result = '';
    let i = 0;

    while (i < text.length) {
        const ch = text[i];

        // Check if this is a digit that should be a subscript
        // It's a subscript if preceded by a letter (element symbol)
        if (/[0-9]/.test(ch) && i > 0 && /[A-Za-z]/.test(text[i - 1])) {
            // Collect all consecutive digits
            let num = '';
            while (i < text.length && /[0-9]/.test(text[i])) {
                num += subscriptMap[text[i]] || text[i];
                i++;
            }
            result += num;
        } else {
            result += ch;
            i++;
        }
    }

    // Replace arrow
    result = result.replace(/→/g, ' → ');

    return result;
}

// ── Load molecule list on startup ───────────

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
    } catch (err) {
        console.warn('Could not load molecule list:', err);
    }
}

function selectMolecule(name) {
    document.getElementById('organic-input').value = name;
    searchOrganic();
}

// ── Health check & init ─────────────────────

async function init() {
    try {
        const res = await fetch('/api/ping');
        const data = await res.json();
        if (data.status === 'ok') {
            console.log('ChemLazy server connected');
        }
    } catch (err) {
        console.warn('Server not reachable:', err);
    }

    loadMoleculeList();
}

init();
