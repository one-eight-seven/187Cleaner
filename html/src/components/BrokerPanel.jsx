import { useState, useEffect, useCallback } from 'react'

const TYPE_ICONS = {
    shell_casing: '🔫', burner_phone: '📱', document: '📄',
    blood_sample: '🩸', knife: '🔪', zip_tie: '🪢',
}

export default function BrokerPanel({ data, onClose }) {
    const [items, setItems]   = useState(data.evidence || [])
    const [selling, setSelling] = useState(null)

    useEffect(() => { setItems(data.evidence || []) }, [data])
    useEffect(() => { S187.onEscape(onClose) }, [onClose])

    const sell = useCallback((id) => {
        setSelling(id)
        S187.post('sellEvidence', { evidenceId: id }).then(() => {
            setSelling(null)
            setItems(prev => prev.filter(e => e.id !== id))
        })
    }, [])

    const mult = data.bonusMultiplier ?? 1.5

    return (
        <div style={{
            position: 'fixed', inset: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 300,
        }}>
            <div className="panel" style={{ width: '500px' }}>
                <div className="panel-header">
                    <div className="panel-title">
                        <div className="icon">🤝</div>
                        Evidence Broker
                        <span className="badge badge-warning" style={{ marginLeft: '8px', fontSize: '10px' }}>×{mult} value</span>
                    </div>
                    <button className="btn-close" onClick={onClose}>✕</button>
                </div>

                <div className="panel-body">
                    {items.length === 0 ? (
                        <div style={{ textAlign: 'center', color: '#475569', padding: '30px 0', fontSize: '14px' }}>
                            No evidence to sell.
                        </div>
                    ) : (
                        <div className="item-list" style={{ maxHeight: '360px', overflowY: 'auto' }}>
                            {items.map(ev => {
                                const payout = Math.floor(ev.evidence_value * mult)
                                return (
                                    <div key={ev.id} className="item">
                                        <div className="item-left">
                                            <div className="item-icon">
                                                {TYPE_ICONS[ev.evidence_type] || '📦'}
                                            </div>
                                            <div>
                                                <div className="item-name" style={{ textTransform: 'capitalize' }}>
                                                    {ev.evidence_type.replace('_', ' ')}
                                                </div>
                                                <div className="item-sub">
                                                    Tier {ev.contract_tier} · Base ${ev.evidence_value?.toLocaleString()}
                                                </div>
                                            </div>
                                        </div>
                                        <button
                                            className="btn btn-primary"
                                            style={{ padding: '6px 14px', fontSize: '12px' }}
                                            disabled={selling === ev.id}
                                            onClick={() => sell(ev.id)}
                                        >
                                            ${payout.toLocaleString()}
                                        </button>
                                    </div>
                                )
                            })}
                        </div>
                    )}
                </div>
            </div>
        </div>
    )
}
