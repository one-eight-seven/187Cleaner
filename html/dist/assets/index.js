/* 187Cleaner — dist/assets/index.js
   Vanilla JS NUI implementation — no framework required */

'use strict';

// ============================================================
// Utilities
// ============================================================
function el(id)    { return document.getElementById(id); }
function show(id)  { el(id).classList.remove('hidden'); }
function hide(id)  { el(id).classList.add('hidden'); }
function fmt(n)    { return Number(n || 0).toLocaleString('en-US'); }
function fmtSec(s) { if (!s) return '--'; return `${Math.floor(s/60)}m ${s%60}s`; }

function closeModal(id) {
    hide(id);
    S187.post('close');
}

// ============================================================
// CONTRACT NOTIFICATION
// ============================================================
const ContractNotif = (() => {
    let timerInterval = null;
    const TIER_COLORS = { 1: '#22c55e', 2: '#f59e0b', 3: '#ef4444' };
    const TIER_LABELS = { 1: 'TIER 1', 2: 'TIER 2', 3: 'TIER 3' };

    function fmtCountdown(s) {
        return `${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`;
    }

    function show(data) {
        const container = el('contract-notif');
        const tier       = data.tier || 1;
        const color      = TIER_COLORS[tier] || '#8b5cf6';

        container.style.borderLeftColor = color;
        container.innerHTML = `
            <div class="cn-header">
                <div style="display:flex;align-items:center;gap:8px;">
                    <span class="cn-tier-badge" style="background:${color}22;border:1px solid ${color}66;color:${color};">${TIER_LABELS[tier]}</span>
                    <span class="cn-title">Contract Incoming</span>
                </div>
                <span class="cn-countdown" id="cn-cd">${fmtCountdown(60)}</span>
            </div>
            ${data.flavour ? `<div style="font-size:12px;color:#64748b;font-style:italic;margin-bottom:10px;line-height:1.5;border-left:2px solid rgba(255,255,255,0.06);padding-left:8px;">${data.flavour}</div>` : ''}
            <div class="cn-details">
                Payout: <span>$${fmt(data.payoutMin)} – $${fmt(data.payoutMax)}</span><br>
                Window: <span>${Math.floor((data.timeWindow||480)/60)} min</span>
            </div>
            <div class="cn-keys">
                <div class="cn-key cn-key-accept"><kbd style="opacity:.7;font-size:11px;margin-right:4px;">Y</kbd> Accept</div>
                <div class="cn-key cn-key-decline"><kbd style="opacity:.7;font-size:11px;margin-right:4px;">N</kbd> Decline</div>
            </div>
        `;

        el('contract-notif').classList.remove('hidden');

        let countdown = 60;
        if (timerInterval) clearInterval(timerInterval);
        timerInterval = setInterval(() => {
            countdown--;
            const cdEl = el('cn-cd');
            if (cdEl) cdEl.textContent = fmtCountdown(countdown);
            if (countdown <= 0) { clearInterval(timerInterval); hide('contract-notif'); }
        }, 1000);
    }

    function close() {
        if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }
        hide('contract-notif');
    }

    return { show, close };
})();

// ============================================================
// SCENE PANEL
// ============================================================
const ScenePanel = (() => {
    let sceneData    = null;
    let timerInterval = null;
    let startTime    = null;
    let timeWindow   = 0;

    function renderTasks(tasks, completedMap) {
        if (!tasks || tasks.length === 0) return '';
        const rows = tasks.map((_, i) => {
            const done = !!completedMap[i];
            return `<div class="task-row ${done ? 'done' : 'pending'}">
                <div class="task-check ${done ? 'checked' : ''}">${done ? '✓' : ''}</div>
                <span>Task ${i + 1}</span>
            </div>`;
        }).join('');
        return rows;
    }

    function buildPanel(data, heat, timer, tasks) {
        const tier  = data.tier || 1;
        const tName = ['', 'T1', 'T2', 'T3'][tier];
        const hColor = heat < 50 ? '#22c55e' : heat < 80 ? '#f59e0b' : '#ef4444';
        const t = tasks || { bodies: {}, surfaces: {}, evidence: {} };

        const bd = data.tasks?.bodies   || [];
        const sf = data.tasks?.surfaces || [];
        const ev = data.tasks?.evidence || [];

        const bodiesHTML   = bd.length   ? `<div class="task-section"><div class="task-section-title">🗃️ Bodies</div>${renderTasks(bd, t.bodies)}</div>`   : '';
        const surfHTML     = sf.length   ? `<div class="task-section"><div class="task-section-title">🧽 Surfaces</div>${renderTasks(sf, t.surfaces)}</div>` : '';
        const evHTML       = ev.length   ? `<div class="task-section"><div class="task-section-title">🔍 Evidence</div>${renderTasks(ev, t.evidence)}</div>` : '';

        return `
            <div class="panel-header" style="padding:12px 14px 10px;">
                <div class="panel-title" style="font-size:14px;">
                    <div class="icon">🧹</div>
                    Scene Assessment
                    <span class="badge badge-warning" style="font-size:10px;padding:1px 6px;">${tName}</span>
                </div>
            </div>
            <div class="panel-body" style="padding:12px 14px;">
                <div class="sp-heat-row">
                    <span style="color:var(--text-secondary);font-size:11px;">Heat</span>
                    <span style="color:${hColor};font-weight:600;font-size:11px;">${heat}%</span>
                </div>
                <div class="progress-bar" style="height:5px;margin-bottom:10px;">
                    <div class="progress-fill" id="sp-heat-fill" style="width:${heat}%;background:linear-gradient(90deg,#22c55e,${hColor});"></div>
                </div>
                <div class="sp-timer" style="color:var(--text-primary);" id="sp-timer">${timer || '--:--'}</div>
                <div class="divider" style="margin:8px 0;"></div>
                ${bodiesHTML}${surfHTML}${evHTML}
            </div>
        `;
    }

    function computeTimer() {
        if (!startTime || !timeWindow) return '--:--';
        const elapsed = Math.floor((Date.now() - startTime) / 1000);
        const left    = Math.max(0, timeWindow - elapsed);
        return `${String(Math.floor(left/60)).padStart(2,'0')}:${String(left%60).padStart(2,'0')}`;
    }

    function open(data) {
        sceneData  = data;
        startTime  = Date.now();
        timeWindow = data.timeWindow || 480;

        const container = el('scene-panel');
        container.innerHTML = buildPanel(data, 0, computeTimer(), null);
        show('scene-panel');

        if (timerInterval) clearInterval(timerInterval);
        timerInterval = setInterval(() => {
            const timerEl = el('sp-timer');
            if (timerEl) timerEl.textContent = computeTimer();
        }, 1000);
    }

    function update(data) {
        if (!sceneData) return;
        const heat = data.heat || 0;
        const tasks = data.tasks || { bodies: {}, surfaces: {}, evidence: {} };

        const heatFill = el('sp-heat-fill');
        if (heatFill) {
            const hColor = heat < 50 ? '#22c55e' : heat < 80 ? '#f59e0b' : '#ef4444';
            heatFill.style.width   = heat + '%';
            heatFill.style.background = `linear-gradient(90deg,#22c55e,${hColor})`;
        }

        // Re-render tasks only
        const container = el('scene-panel');
        if (!container) return;
        const timer = data.timer || computeTimer();
        container.innerHTML = buildPanel(sceneData, heat, timer, tasks);
    }

    function close() {
        if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }
        hide('scene-panel');
        sceneData = null;
    }

    return { open, update, close };
})();

// ============================================================
// EVIDENCE MODAL
// ============================================================
const EvidenceModal = (() => {
    let countdownInterval = null;
    let currentData       = null;

    function decide(decision) {
        if (countdownInterval) { clearInterval(countdownInterval); countdownInterval = null; }
        S187.post('evidenceDecision', { id: currentData?.id, decision });
        hide('evidence-modal');
        currentData = null;
    }

    function open(data) {
        currentData = data;
        const inner = el('evidence-modal').querySelector('.panel');
        inner.innerHTML = `
            <div class="panel-header">
                <div class="panel-title"><div class="icon">🔍</div>Evidence Found</div>
            </div>
            <div class="panel-body">
                <div style="text-align:center;padding:10px 0 14px;font-size:16px;font-weight:600;">${data.label}</div>
                <div class="divider"></div>
                <div class="choice-grid">
                    <div class="choice-card success-card" id="ev-destroy">
                        <div class="choice-icon">🔥</div>
                        <div class="choice-label">Destroy</div>
                        <div class="choice-sub">+${data.repGain || 5} Cleaner Rep · No risk</div>
                    </div>
                    <div class="choice-card warning-card" id="ev-pocket">
                        <div class="choice-icon">💰</div>
                        <div class="choice-label">Pocket</div>
                        <div class="choice-sub">$${fmt(data.pocketValue)} · ${data.betrayalChance || 20}% betrayal risk</div>
                    </div>
                </div>
                <div class="auto-countdown">Auto-destroy in <span id="ev-cd" style="font-weight:600;">15s</span></div>
            </div>
        `;

        el('ev-destroy').onclick = () => decide('destroy');
        el('ev-pocket').onclick  = () => decide('pocket');

        show('evidence-modal');

        let cd = 15;
        if (countdownInterval) clearInterval(countdownInterval);
        countdownInterval = setInterval(() => {
            cd--;
            const cdEl = el('ev-cd');
            if (cdEl) { cdEl.textContent = `${cd}s`; cdEl.style.color = cd <= 5 ? '#ef4444' : '#94a3b8'; }
            if (cd <= 0) decide('destroy');
        }, 1000);
    }

    function close() {
        if (countdownInterval) { clearInterval(countdownInterval); countdownInterval = null; }
        hide('evidence-modal');
        currentData = null;
    }

    return { open, close };
})();

// ============================================================
// WITNESS MODAL
// ============================================================
const WitnessModal = (() => {
    let countdownInterval = null;

    function decide(decision) {
        if (countdownInterval) { clearInterval(countdownInterval); countdownInterval = null; }
        S187.post('witnessDecision', { decision });
        hide('witness-modal');
    }

    function open(data) {
        const inner = el('witness-modal').querySelector('.panel');
        inner.innerHTML = `
            <div class="panel-header">
                <div class="panel-title">
                    <div class="icon" style="background:rgba(245,158,11,0.2);border-color:#f59e0b;">👁️</div>
                    Witness Spotted
                </div>
            </div>
            <div class="panel-body">
                <p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;line-height:1.6;">
                    Someone has seen too much. Act fast before they call the police.
                </p>
                <div class="divider" style="margin:0 0 16px;"></div>
                <div class="choice-grid">
                    <div class="choice-card" id="wt-pay">
                        <div class="choice-icon">💵</div>
                        <div class="choice-label">Pay Off</div>
                        <div class="choice-sub" style="color:#ef4444;">–$${fmt(data.payoffCost)} from payout</div>
                    </div>
                    <div class="choice-card accent-card" id="wt-report">
                        <div class="choice-icon">📞</div>
                        <div class="choice-label">Report to Client</div>
                        <div class="choice-sub">No cost · Rep risk</div>
                    </div>
                </div>
                <div class="auto-countdown" style="margin-top:14px;">
                    Police called in <span id="wt-cd" style="font-weight:600;">30s</span> if ignored
                </div>
            </div>
        `;

        el('wt-pay').onclick    = () => decide('pay');
        el('wt-report').onclick = () => decide('report');

        show('witness-modal');
        S187.onEscape(() => decide('ignore'));

        let cd = 30;
        if (countdownInterval) clearInterval(countdownInterval);
        countdownInterval = setInterval(() => {
            cd--;
            const cdEl = el('wt-cd');
            if (cdEl) { cdEl.textContent = `${cd}s`; cdEl.style.color = cd <= 10 ? '#ef4444' : '#94a3b8'; }
            if (cd <= 0) {
                clearInterval(countdownInterval);
                hide('witness-modal');
                S187.post('witnessDecision', { decision: 'ignore' });
            }
        }, 1000);
    }

    function close() {
        if (countdownInterval) { clearInterval(countdownInterval); countdownInterval = null; }
        hide('witness-modal');
    }

    return { open, close };
})();

// ============================================================
// UPGRADE SHOP
// ============================================================
const ShopPanel = (() => {
    const ICONS  = { 1: '🧰', 2: '🔦', 3: '🧪' };
    const NAMES  = { 1: 'Field Kit', 2: 'UV Scanner Kit', 3: 'Chemical Kit' };
    const DESCS  = {
        1: 'Faster clean animations (–30%) · Extended bag radius',
        2: 'Reveals hidden bonus evidence worth 3× · Double bag capacity',
        3: 'Heat gain rate –40% · Leaves no surface trace',
    };

    function renderCard(tier, owned, locked, price, canAfford) {
        return `
            <div class="upgrade-card ${owned ? 'owned' : ''}">
                <div class="upgrade-header">
                    <span class="upgrade-icon">${ICONS[tier]}</span>
                    <div>
                        <div class="upgrade-name">Tier ${tier} — ${NAMES[tier]}</div>
                        <div class="upgrade-desc">${DESCS[tier]}</div>
                    </div>
                    ${owned ? '<span class="badge badge-success" style="margin-left:auto;">Owned</span>' : ''}
                </div>
                ${!owned ? `
                <div class="upgrade-footer">
                    <span class="upgrade-price" style="color:${canAfford ? 'var(--text-primary)' : '#ef4444'};">$${fmt(price)}</span>
                    <button class="btn btn-primary" style="padding:7px 18px;font-size:12px;"
                        ${locked || !canAfford ? 'disabled' : ''}
                        onclick="ShopPanel.buy(${tier})"
                    >${locked ? 'Locked' : 'Purchase'}</button>
                </div>` : ''}
            </div>
        `;
    }

    function open(data) {
        const inner = el('shop-panel').querySelector('.panel');
        const kitTier = data.kitTier || 0;
        const money   = data.money   || 0;
        const prices  = data.upgrades || [0, 10000, 28000, 55000];

        inner.innerHTML = `
            <div class="panel-header">
                <div class="panel-title"><div class="icon">🧰</div>Cleaner Kit Shop</div>
                <button class="btn-close" onclick="ShopPanel.close()">✕</button>
            </div>
            <div class="panel-body">
                <div class="info-bar">
                    Balance: <span>$${fmt(money)}</span>
                    <span style="margin-left:12px;">Cleaner Rep: <span style="color:var(--accent);">${fmt(data.cleanerRep)}</span></span>
                </div>
                <div class="upgrade-list">
                    ${[1,2,3].map(t => renderCard(
                        t,
                        kitTier >= t,
                        kitTier < t - 1,
                        prices[t] || 0,
                        money >= (prices[t] || 0)
                    )).join('')}
                </div>
            </div>
        `;

        show('shop-panel');
    }

    function buy(tier) {
        S187.post('purchaseUpgrade', { tier });
    }

    function close() {
        hide('shop-panel');
        S187.post('closeShop');
    }

    return { open, buy, close };
})();

// expose for onclick handlers
window.ShopPanel = ShopPanel;

// ============================================================
// STATS PANEL
// ============================================================
const StatsPanel = (() => {
    function getTitle(d) {
        if ((d.totalContracts||0) >= 100 && (d.evidenceDestroyed||0) > (d.evidenceSoldCount||0) * 3) return 'The Loyal Hand';
        if ((d.brokerRep||0) >= 300) return 'The Broker';
        if (d.fastestClean && d.fastestClean < 120) return 'Ghost';
        if ((d.totalContracts||0) >= 50) return 'Veteran Cleaner';
        if ((d.totalContracts||0) >= 10) return 'Reliable Hand';
        return 'Novice Cleaner';
    }

    function repBar(label, value, max, color) {
        const pct = Math.min(100, ((value || 0) / max) * 100);
        return `
            <div class="rep-section">
                <div class="rep-label-row">
                    <span style="color:var(--text-secondary);">${label}</span>
                    <span style="color:${color};font-weight:700;">${fmt(value)} / ${fmt(max)}</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width:${pct}%;background:${color};"></div>
                </div>
            </div>
        `;
    }

    function statCard(value, label, span) {
        return `<div class="stat-card" ${span ? `style="grid-column:span ${span};"` : ''}>
            <div class="stat-value">${value}</div>
            <div class="stat-label">${label}</div>
        </div>`;
    }

    function open(data) {
        const inner = el('stats-panel').querySelector('.panel');
        const title = getTitle(data);
        const tier  = data.kitTier === 0 ? 'None' : `Tier ${data.kitTier}`;

        inner.innerHTML = `
            <div class="panel-header">
                <div class="panel-title"><div class="icon">📊</div>Cleaner Statistics</div>
                <button class="btn-close" onclick="StatsPanel.close()">✕</button>
            </div>
            <div class="panel-body">
                <div style="text-align:center;margin-bottom:18px;">
                    <div style="font-size:11px;color:var(--accent);text-transform:uppercase;letter-spacing:1px;margin-bottom:4px;">Current Title</div>
                    <div style="font-size:20px;font-weight:700;">${title}</div>
                    <div style="font-size:12px;color:var(--text-secondary);margin-top:4px;">Kit Tier: <span style="color:#a78bfa;font-weight:600;">${tier}</span></div>
                </div>
                ${repBar('Cleaner Reputation', data.cleanerRep, 500, '#8b5cf6')}
                ${repBar('Broker Reputation',  data.brokerRep,  500, '#f59e0b')}
                <div class="divider"></div>
                <div class="stat-grid" style="margin-top:12px;">
                    ${statCard(fmt(data.totalContracts),    'Contracts')}
                    ${statCard('$' + fmt(data.totalEarned), 'Earned')}
                    ${statCard(fmt(data.totalBodies),       'Bodies Disposed')}
                    ${statCard(fmt(data.evidenceDestroyed), 'Evidence Destroyed')}
                    ${statCard(fmt(data.evidenceSoldCount), 'Evidence Sold')}
                    ${statCard(fmt(data.betrayals),         'Betrayals')}
                    ${statCard(fmtSec(data.fastestClean),   'Fastest Clean', 2)}
                    ${statCard('$' + fmt(data.evidenceSoldValue), 'Broker Revenue', 2)}
                    ${statCard((data.currentStreak||0)+'🔥', 'Clean Streak (Best: '+(data.bestStreak||0)+')', 2)}
                </div>
                <div id="stats-leaderboard"></div>
            </div>
        `;

        show('stats-panel');
    }

    function updateLeaderboard(lb) {
        const el2 = document.getElementById('stats-leaderboard');
        if (!el2 || !lb || !lb.length) return;
        el2.innerHTML = `
            <hr style="border:none;border-top:1px solid rgba(255,255,255,0.06);margin:14px 0 10px;">
            <div style="font-size:11px;color:#8b5cf6;text-transform:uppercase;letter-spacing:.5px;margin-bottom:8px;">Server Records — Fastest Clean</div>
            ${lb.map((r,i) => `<div style="display:flex;justify-content:space-between;padding:6px 10px;border-radius:6px;background:${i===0?'rgba(139,92,246,.1)':'rgba(255,255,255,.03)'};margin-bottom:4px;font-size:12px;">
                <span style="color:${i===0?'#a78bfa':'#94a3b8'}">#${i+1} ${(r.identifier||'').substring(0,12)}…</span>
                <span style="color:#f1f5f9;font-weight:600;">${fmtSec(r.fastest_clean)}</span>
            </div>`).join('')}
        `;
    }

    function close() {
        hide('stats-panel');
        S187.post('closeStats');
    }

    return { open, close, updateLeaderboard };
})();

window.StatsPanel = StatsPanel;

// ============================================================
// BROKER PANEL
// ============================================================
const BrokerPanel = (() => {
    const TYPE_ICONS = {
        shell_casing: '🔫', burner_phone: '📱', document: '📄',
        blood_sample: '🩸', knife: '🔪', zip_tie: '🪢',
    };

    let multiplier = 1.5;

    function renderItems(items) {
        if (!items || items.length === 0) {
            return '<div class="broker-empty">No evidence to sell.</div>';
        }
        return items.map(ev => {
            const payout = Math.floor((ev.evidence_value || 0) * multiplier);
            const label  = (ev.evidence_type || '').replace('_', ' ');
            return `
                <div class="item broker-item">
                    <div class="item-left">
                        <div class="item-icon">${TYPE_ICONS[ev.evidence_type] || '📦'}</div>
                        <div>
                            <div class="item-name" style="text-transform:capitalize;">${label}</div>
                            <div class="item-sub">Tier ${ev.contract_tier} · Base $${fmt(ev.evidence_value)}</div>
                        </div>
                    </div>
                    <button class="btn btn-primary" style="padding:6px 14px;font-size:12px;"
                        onclick="BrokerPanel.sell(${ev.id})">$${fmt(payout)}</button>
                </div>
            `;
        }).join('');
    }

    function open(data) {
        multiplier = data.bonusMultiplier || 1.5;
        const inner = el('broker-panel').querySelector('.panel');
        inner.innerHTML = `
            <div class="panel-header">
                <div class="panel-title">
                    <div class="icon">🤝</div>
                    Evidence Broker
                    <span class="badge badge-warning" style="margin-left:8px;font-size:10px;">×${multiplier} value</span>
                </div>
                <button class="btn-close" onclick="BrokerPanel.close()">✕</button>
            </div>
            <div class="panel-body">
                <div class="item-list" id="broker-list" style="max-height:380px;overflow-y:auto;">
                    ${renderItems(data.evidence)}
                </div>
            </div>
        `;

        show('broker-panel');
    }

    function sell(id) {
        S187.post('sellEvidence', { evidenceId: id });
        // Remove row optimistically
        const listEl = el('broker-list');
        if (!listEl) return;
        // Re-query items after sell via event
    }

    function removeSold(id) {
        const listEl = el('broker-list');
        if (!listEl) return;
        // Simple re-render by removing the item
        const buttons = listEl.querySelectorAll('.btn');
        buttons.forEach(btn => {
            if (btn.getAttribute('onclick') === `BrokerPanel.sell(${id})`) {
                btn.closest('.item').remove();
            }
        });
        if (listEl.querySelectorAll('.item').length === 0) {
            listEl.innerHTML = '<div class="broker-empty">No evidence to sell.</div>';
        }
    }

    function close() {
        hide('broker-panel');
        S187.post('closeBroker');
    }

    return { open, sell, removeSold, close };
})();

window.BrokerPanel = BrokerPanel;

// ============================================================
// PAYOUT SCREEN
// ============================================================
const PayoutScreen = (() => {
    const BONUS_LABELS = {
        ghost: '👻 Ghost Bonus +50%',
        time:  '⏱ Time Bonus +25%',
    };
    const TIER_LABELS = ['', 'Tier 1', 'Tier 2', 'Tier 3'];

    function open(data) {
        const container = el('payout-screen');
        const bonusLine = data.bonusType && data.bonusType !== 'none'
            ? `<div class="payout-line payout-bonus"><span>${BONUS_LABELS[data.bonusType]||''}</span><span>×${(data.multiplier||1).toFixed(2)}</span></div>`
            : '';
        const timeLine = data.elapsed
            ? `<div class="payout-line"><span style="color:var(--text-secondary);">Scene cleared in</span><span>${fmtSec(data.elapsed)}</span></div>`
            : '';

        container.innerHTML = `
            <div class="payout-card">
                <div class="payout-subtitle">${TIER_LABELS[data.tier]||''} Contract</div>
                <div class="payout-title">Contract Complete</div>
                <div>
                    <div class="payout-line">
                        <span style="color:var(--text-secondary);">Base Payout</span>
                        <span>$${fmt(data.base)}</span>
                    </div>
                    ${bonusLine}
                    ${timeLine}
                </div>
                <div class="payout-divider"></div>
                <div class="payout-total">
                    <span class="payout-total-label">Total Payout</span>
                    <span class="payout-total-value">$${fmt(data.total)}</span>
                </div>
            </div>
        `;

        show('payout-screen');
    }

    function close() { hide('payout-screen'); }

    return { open, close };
})();

// ============================================================
// MESSAGE ROUTER
// ============================================================
window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};
    switch (action) {
        case 'showContract':         ContractNotif.show(data);   break;
        case 'hideContract':         ContractNotif.close();      break;

        case 'showScene':            ScenePanel.open(data);      break;
        case 'hideScene':            ScenePanel.close();         break;
        case 'updateScene':          ScenePanel.update(data);    break;

        case 'showEvidenceDecision': EvidenceModal.open(data);   break;
        case 'hideEvidence':         EvidenceModal.close();      break;

        case 'showWitness':          WitnessModal.open(data);    break;
        case 'hideWitness':          WitnessModal.close();       break;

        case 'openShop':             ShopPanel.open(data);       break;
        case 'hideShop':             ShopPanel.close();          break;

        case 'openStats':            StatsPanel.open(data);            break;
        case 'hideStats':            StatsPanel.close();               break;
        case 'updateLeaderboard':    StatsPanel.updateLeaderboard(data); break;

        case 'openBroker':           BrokerPanel.open(data);     break;
        case 'hideBroker':           BrokerPanel.close();        break;
        case 'brokerItemSold':       BrokerPanel.removeSold(e.data.data && e.data.data.id); break;

        case 'showPayout':           PayoutScreen.open(data);    break;
        case 'hidePayout':           PayoutScreen.close();       break;

        default: break;
    }
});
