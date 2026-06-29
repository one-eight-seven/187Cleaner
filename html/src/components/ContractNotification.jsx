import { useState, useEffect } from 'react'

const TIER_COLORS = { 1: '#22c55e', 2: '#f59e0b', 3: '#ef4444' }
const TIER_LABELS = { 1: 'TIER 1', 2: 'TIER 2', 3: 'TIER 3' }

function fmt(sec) {
    return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`
}

export default function ContractNotification({ data }) {
    const [countdown, setCountdown] = useState(60)

    useEffect(() => {
        if (countdown <= 0) return
        const id = setInterval(() => setCountdown(c => c - 1), 1000)
        return () => clearInterval(id)
    }, [countdown])

    const tierColor = TIER_COLORS[data.tier] || '#8b5cf6'

    return (
        <div style={{
            position: 'fixed', top: '20px', left: '50%', transform: 'translateX(-50%)',
            width: '360px', zIndex: 200,
            background: 'rgba(14,10,28,0.97)',
            border: `1px solid rgba(255,255,255,0.10)`,
            borderLeft: `3px solid ${tierColor}`,
            borderRadius: '12px',
            boxShadow: '0 8px 32px rgba(0,0,0,0.6)',
            padding: '16px 18px',
            animation: 'panelIn 0.25s cubic-bezier(0.34,1.56,0.64,1)',
            fontFamily: 'Inter, sans-serif',
            color: '#f1f5f9',
        }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <span style={{
                        padding: '2px 8px', borderRadius: '999px', fontSize: '11px', fontWeight: 700,
                        background: `${tierColor}22`, border: `1px solid ${tierColor}66`, color: tierColor,
                        letterSpacing: '0.5px'
                    }}>{TIER_LABELS[data.tier]}</span>
                    <span style={{ fontSize: '13px', fontWeight: 600 }}>Contract Incoming</span>
                </div>
                <span style={{ fontSize: '12px', color: '#94a3b8' }}>{fmt(countdown)}</span>
            </div>

            {data.flavour && (
                <div style={{
                    fontSize: '12px', color: '#64748b', fontStyle: 'italic',
                    marginBottom: '10px', lineHeight: '1.5',
                    borderLeft: '2px solid rgba(255,255,255,0.06)', paddingLeft: '8px',
                }}>
                    {data.flavour}
                </div>
            )}

            <div style={{ fontSize: '13px', color: '#94a3b8', marginBottom: '12px', lineHeight: '1.5' }}>
                <div>Payout: <span style={{ color: '#f1f5f9', fontWeight: 600 }}>
                    ${data.payoutMin?.toLocaleString()} – ${data.payoutMax?.toLocaleString()}
                </span></div>
                <div>Time window: <span style={{ color: '#f1f5f9', fontWeight: 600 }}>
                    {Math.floor(data.timeWindow / 60)} min
                </span></div>
            </div>

            <div style={{
                display: 'flex', gap: '8px',
                padding: '10px 0 0', borderTop: '1px solid rgba(255,255,255,0.08)',
            }}>
                <div style={{
                    flex: 1, textAlign: 'center', padding: '7px',
                    background: 'rgba(34,197,94,0.12)', border: '1px solid rgba(34,197,94,0.35)',
                    borderRadius: '8px', fontSize: '13px', fontWeight: 600, color: '#22c55e',
                }}>
                    <kbd style={{ opacity: 0.7, fontSize: '11px', marginRight: '4px' }}>Y</kbd> Accept
                </div>
                <div style={{
                    flex: 1, textAlign: 'center', padding: '7px',
                    background: 'rgba(239,68,68,0.10)', border: '1px solid rgba(239,68,68,0.3)',
                    borderRadius: '8px', fontSize: '13px', fontWeight: 600, color: '#ef4444',
                }}>
                    <kbd style={{ opacity: 0.7, fontSize: '11px', marginRight: '4px' }}>N</kbd> Decline
                </div>
            </div>
        </div>
    )
}
