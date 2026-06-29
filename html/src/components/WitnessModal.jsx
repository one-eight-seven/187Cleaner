import { useState, useEffect, useCallback } from 'react'

export default function WitnessModal({ data, onClose }) {
    const [countdown, setCountdown] = useState(30)

    const decide = useCallback((decision) => {
        S187.post('witnessDecision', { decision })
        onClose()
    }, [onClose])

    useEffect(() => {
        if (countdown <= 0) { decide('ignore'); return }
        const id = setInterval(() => setCountdown(c => c - 1), 1000)
        return () => clearInterval(id)
    }, [countdown, decide])

    return (
        <div style={{
            position: 'fixed', inset: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 300,
        }}>
            <div className="panel" style={{ width: '440px' }}>
                <div className="panel-header">
                    <div className="panel-title">
                        <div className="icon" style={{ background: 'rgba(245,158,11,0.2)', borderColor: '#f59e0b' }}>👁️</div>
                        Witness Spotted
                    </div>
                </div>

                <div className="panel-body">
                    <p style={{ fontSize: '13px', color: '#94a3b8', marginBottom: '16px', lineHeight: '1.6' }}>
                        Someone has seen too much. Act fast before they call the police.
                    </p>

                    <div className="divider" style={{ margin: '0 0 16px' }} />

                    <div style={{ display: 'flex', gap: '12px' }}>
                        <button
                            className="btn btn-secondary"
                            style={{ flex: 1, flexDirection: 'column', height: '80px', gap: '4px' }}
                            onClick={() => decide('pay')}
                        >
                            <span style={{ fontSize: '20px' }}>💵</span>
                            <span style={{ fontWeight: 700 }}>Pay Off</span>
                            <span style={{ fontSize: '11px', color: '#ef4444' }}>–${data.payoffCost} from payout</span>
                        </button>

                        <button
                            className="btn btn-secondary"
                            style={{
                                flex: 1, flexDirection: 'column', height: '80px', gap: '4px',
                                borderColor: 'rgba(139,92,246,0.4)', color: '#a78bfa',
                            }}
                            onClick={() => decide('report')}
                        >
                            <span style={{ fontSize: '20px' }}>📞</span>
                            <span style={{ fontWeight: 700 }}>Report to Client</span>
                            <span style={{ fontSize: '11px', opacity: 0.7 }}>No cost · Rep risk</span>
                        </button>
                    </div>

                    <div style={{
                        textAlign: 'center', marginTop: '14px', fontSize: '12px',
                        color: countdown <= 10 ? '#ef4444' : '#475569',
                    }}>
                        Police called in <span style={{ fontWeight: 600 }}>{countdown}s</span> if ignored
                    </div>
                </div>
            </div>
        </div>
    )
}
