const BONUS_LABELS = {
    ghost: '👻 Ghost Bonus +50%',
    time:  '⏱ Time Bonus +25%',
    none:  '',
}

const TIER_LABELS = { 1: 'Tier 1', 2: 'Tier 2', 3: 'Tier 3' }

function fmtTime(sec) {
    if (!sec) return ''
    return `${Math.floor(sec / 60)}m ${sec % 60}s`
}

export default function PayoutScreen({ data }) {
    const bonus = data.bonusType !== 'none' ? BONUS_LABELS[data.bonusType] : null

    return (
        <div style={{
            position: 'fixed', inset: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: 'rgba(0,0,0,0.35)',
            zIndex: 400,
            animation: 'panelIn 0.4s ease',
        }}>
            <div style={{
                background: 'rgba(14,10,28,0.97)',
                border: '1px solid rgba(139,92,246,0.4)',
                borderRadius: '20px',
                boxShadow: '0 0 60px rgba(139,92,246,0.25), 0 8px 32px rgba(0,0,0,0.7)',
                padding: '40px 50px',
                minWidth: '380px',
                textAlign: 'center',
                fontFamily: 'Inter, sans-serif',
                color: '#f1f5f9',
            }}>
                <div style={{ fontSize: '12px', color: '#8b5cf6', textTransform: 'uppercase', letterSpacing: '2px', marginBottom: '8px' }}>
                    {TIER_LABELS[data.tier]} Contract
                </div>
                <div style={{ fontSize: '26px', fontWeight: 700, marginBottom: '24px' }}>
                    Contract Complete
                </div>

                <div style={{ marginBottom: '20px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px' }}>
                        <span style={{ color: '#94a3b8' }}>Base Payout</span>
                        <span>${(data.base || 0).toLocaleString()}</span>
                    </div>
                    {bonus && (
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px', color: '#22c55e' }}>
                            <span>{bonus}</span>
                            <span>×{data.multiplier?.toFixed(2)}</span>
                        </div>
                    )}
                    {data.elapsed && (
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', color: '#475569' }}>
                            <span>Scene cleared in</span>
                            <span>{fmtTime(data.elapsed)}</span>
                        </div>
                    )}
                </div>

                <div style={{
                    borderTop: '1px solid rgba(255,255,255,0.10)',
                    paddingTop: '20px',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                }}>
                    <span style={{ fontSize: '14px', color: '#94a3b8' }}>Total Payout</span>
                    <span style={{
                        fontSize: '28px', fontWeight: 800, color: '#22c55e',
                        textShadow: '0 0 20px rgba(34,197,94,0.5)',
                    }}>
                        ${(data.total || 0).toLocaleString()}
                    </span>
                </div>
            </div>
        </div>
    )
}
