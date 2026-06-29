import { useState, useEffect, useCallback } from 'react'

export default function EvidenceModal({ data, onClose }) {
    const [countdown, setCountdown] = useState(15)

    const decide = useCallback((decision) => {
        S187.post('evidenceDecision', { id: data.id, decision })
        onClose(decision)
    }, [data, onClose])

    useEffect(() => {
        if (countdown <= 0) { decide('destroy'); return }
        const id = setInterval(() => setCountdown(c => c - 1), 1000)
        return () => clearInterval(id)
    }, [countdown, decide])

    useEffect(() => {
        S187.onEscape(() => decide('destroy'))
    }, [decide])

    return (
        <div style={{
            position: 'fixed', inset: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 300,
        }}>
            <div className="panel" style={{ width: '460px' }}>
                <div className="panel-header">
                    <div className="panel-title">
                        <div className="icon">🔍</div>
                        Evidence Found
                    </div>
                </div>

                <div className="panel-body">
                    <div style={{
                        textAlign: 'center', padding: '10px 0 14px',
                        fontSize: '16px', fontWeight: 600, color: '#f1f5f9',
                    }}>
                        {data.label}
                    </div>

                    <div className="divider" />

                    <div style={{ display: 'flex', gap: '12px', marginTop: '14px' }}>
                        {/* Destroy */}
                        <button
                            className="btn btn-success"
                            style={{ flex: 1, flexDirection: 'column', height: '90px', gap: '4px' }}
                            onClick={() => decide('destroy')}
                        >
                            <span style={{ fontSize: '22px' }}>🔥</span>
                            <span style={{ fontWeight: 700 }}>Destroy</span>
                            <span style={{ fontSize: '11px', opacity: 0.8 }}>+{data.repGain} Cleaner Rep · No risk</span>
                        </button>

                        {/* Pocket */}
                        <button
                            className="btn btn-secondary"
                            style={{
                                flex: 1, flexDirection: 'column', height: '90px', gap: '4px',
                                borderColor: 'rgba(245,158,11,0.4)', color: '#f59e0b',
                            }}
                            onClick={() => decide('pocket')}
                        >
                            <span style={{ fontSize: '22px' }}>💰</span>
                            <span style={{ fontWeight: 700 }}>Pocket</span>
                            <span style={{ fontSize: '11px', opacity: 0.8 }}>
                                ${data.pocketValue?.toLocaleString()} · {data.betrayalChance}% betrayal risk
                            </span>
                        </button>
                    </div>

                    <div style={{
                        textAlign: 'center', marginTop: '12px', fontSize: '12px', color: '#475569',
                    }}>
                        Auto-destroy in <span style={{ color: countdown <= 5 ? '#ef4444' : '#94a3b8', fontWeight: 600 }}>{countdown}s</span>
                    </div>
                </div>
            </div>
        </div>
    )
}
