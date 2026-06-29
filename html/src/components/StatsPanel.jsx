import { useEffect } from 'react'

function fmt(n) { return Number(n || 0).toLocaleString() }
function fmtTime(sec) {
    if (!sec) return '--'
    const m = Math.floor(sec / 60), s = sec % 60
    return `${m}m ${s}s`
}

function RepBar({ label, value, max = 1000, color = '#8b5cf6' }) {
    const pct = Math.min(100, (value / max) * 100)
    return (
        <div style={{ marginBottom: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '4px', fontSize: '12px' }}>
                <span style={{ color: '#94a3b8' }}>{label}</span>
                <span style={{ color, fontWeight: 700 }}>{fmt(value)} / {fmt(max)}</span>
            </div>
            <div className="progress-bar">
                <div className="progress-fill" style={{ width: `${pct}%`, background: color }} />
            </div>
        </div>
    )
}

function getTitle(data) {
    if (data.totalContracts >= 100 && data.evidenceDestroyed > data.evidenceSoldCount * 3) return 'The Loyal Hand'
    if (data.brokerRep >= 300) return 'The Broker'
    if (data.fastestClean && data.fastestClean < 120) return 'Ghost'
    if (data.totalContracts >= 50) return 'Veteran Cleaner'
    if (data.totalContracts >= 10) return 'Reliable Hand'
    return 'Novice Cleaner'
}

export default function StatsPanel({ data, onClose }) {
    useEffect(() => { S187.onEscape(onClose) }, [onClose])

    const title = getTitle(data)

    return (
        <div style={{
            position: 'fixed', inset: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 300,
        }}>
            <div className="panel" style={{ width: '620px' }}>
                <div className="panel-header">
                    <div className="panel-title">
                        <div className="icon">📊</div>
                        Cleaner Statistics
                    </div>
                    <button className="btn-close" onClick={onClose}>✕</button>
                </div>

                <div className="panel-body">
                    {/* Title */}
                    <div style={{ textAlign: 'center', marginBottom: '18px' }}>
                        <div style={{ fontSize: '11px', color: '#8b5cf6', textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '4px' }}>
                            Current Title
                        </div>
                        <div style={{ fontSize: '20px', fontWeight: 700, color: '#f1f5f9' }}>{title}</div>
                        <div style={{ fontSize: '12px', color: '#94a3b8', marginTop: '4px' }}>
                            Kit Tier: <span style={{ color: '#a78bfa', fontWeight: 600 }}>{data.kitTier === 0 ? 'None' : `Tier ${data.kitTier}`}</span>
                        </div>
                    </div>

                    {/* Reputation */}
                    <RepBar label="Cleaner Reputation" value={data.cleanerRep} max={500} color="#8b5cf6" />
                    <RepBar label="Broker Reputation"  value={data.brokerRep}  max={500} color="#f59e0b" />

                    <div className="divider" />

                    {/* Stat grid */}
                    <div className="stat-grid" style={{ marginTop: '12px' }}>
                        <div className="stat-card">
                            <div className="stat-value">{fmt(data.totalContracts)}</div>
                            <div className="stat-label">Contracts</div>
                        </div>
                        <div className="stat-card">
                            <div className="stat-value">${fmt(data.totalEarned)}</div>
                            <div className="stat-label">Earned</div>
                        </div>
                        <div className="stat-card">
                            <div className="stat-value">{fmt(data.totalBodies)}</div>
                            <div className="stat-label">Bodies Disposed</div>
                        </div>
                        <div className="stat-card">
                            <div className="stat-value">{fmt(data.evidenceDestroyed)}</div>
                            <div className="stat-label">Evidence Destroyed</div>
                        </div>
                        <div className="stat-card">
                            <div className="stat-value">{fmt(data.evidenceSoldCount)}</div>
                            <div className="stat-label">Evidence Sold</div>
                        </div>
                        <div className="stat-card">
                            <div className="stat-value">{fmt(data.betrayals)}</div>
                            <div className="stat-label">Betrayals</div>
                        </div>
                        <div className="stat-card" style={{ gridColumn: 'span 2' }}>
                            <div className="stat-value">{fmtTime(data.fastestClean)}</div>
                            <div className="stat-label">Fastest Clean</div>
                        </div>
                        <div className="stat-card" style={{ gridColumn: 'span 2' }}>
                            <div className="stat-value">${fmt(data.evidenceSoldValue)}</div>
                            <div className="stat-label">Broker Revenue</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}
