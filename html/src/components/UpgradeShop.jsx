import { useState, useEffect, useCallback } from 'react'

const TIER_ICONS  = { 1: '🧰', 2: '🔦', 3: '🧪' }
const TIER_NAMES  = { 1: 'Field Kit', 2: 'UV Scanner Kit', 3: 'Chemical Kit' }
const TIER_DESCS  = {
    1: 'Faster clean animations (–30%) · Extended bag radius',
    2: 'Reveals hidden bonus evidence worth 3× · Double bag capacity',
    3: 'Heat gain rate –40% · Leaves no surface trace',
}

export default function UpgradeShop({ data, onClose }) {
    const [buying, setBuying] = useState(null)
    const [shopData, setShopData] = useState(data)

    useEffect(() => { setShopData(data) }, [data])

    useEffect(() => { S187.onEscape(onClose) }, [onClose])

    const purchase = useCallback((tier) => {
        setBuying(tier)
        S187.post('purchaseUpgrade', { tier }).then(() => {
            setBuying(null)
        })
    }, [])

    const renderUpgrade = (tier) => {
        const price    = shopData.upgrades?.[tier] ?? 0
        const owned    = (shopData.kitTier ?? 0) >= tier
        const locked   = (shopData.kitTier ?? 0) < tier - 1
        const canAfford= (shopData.money ?? 0) >= price
        const isBuying = buying === tier

        return (
            <div key={tier} style={{
                padding: '16px', borderRadius: '12px',
                background: owned ? 'rgba(34,197,94,0.08)' : 'rgba(255,255,255,0.03)',
                border: owned ? '1px solid rgba(34,197,94,0.35)' : '1px solid rgba(255,255,255,0.10)',
                display: 'flex', flexDirection: 'column', gap: '10px',
            }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <span style={{ fontSize: '24px' }}>{TIER_ICONS[tier]}</span>
                    <div>
                        <div style={{ fontWeight: 600, fontSize: '14px' }}>
                            Tier {tier} — {TIER_NAMES[tier]}
                        </div>
                        <div style={{ fontSize: '12px', color: '#94a3b8', marginTop: '2px' }}>
                            {TIER_DESCS[tier]}
                        </div>
                    </div>
                    {owned && (
                        <span className="badge badge-success" style={{ marginLeft: 'auto' }}>Owned</span>
                    )}
                </div>

                {!owned && (
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <span style={{ fontWeight: 700, color: canAfford ? '#f1f5f9' : '#ef4444', fontSize: '15px' }}>
                            ${price.toLocaleString()}
                        </span>
                        <button
                            className="btn btn-primary"
                            disabled={locked || !canAfford || isBuying}
                            style={{ padding: '7px 18px', fontSize: '12px' }}
                            onClick={() => purchase(tier)}
                        >
                            {isBuying ? 'Purchasing...' : locked ? 'Locked' : 'Purchase'}
                        </button>
                    </div>
                )}
            </div>
        )
    }

    return (
        <div style={{
            position: 'fixed', inset: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            zIndex: 300,
        }}>
            <div className="panel" style={{ width: '520px' }}>
                <div className="panel-header">
                    <div className="panel-title">
                        <div className="icon">🧰</div>
                        Cleaner Kit Shop
                    </div>
                    <button className="btn-close" onClick={onClose}>✕</button>
                </div>

                <div className="panel-body">
                    <div style={{ fontSize: '12px', color: '#94a3b8', marginBottom: '14px' }}>
                        Balance: <span style={{ color: '#f1f5f9', fontWeight: 600 }}>
                            ${(shopData.money ?? 0).toLocaleString()}
                        </span>
                        <span style={{ marginLeft: '12px' }}>
                            Cleaner Rep: <span style={{ color: '#8b5cf6', fontWeight: 600 }}>{shopData.cleanerRep ?? 0}</span>
                        </span>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                        {[1, 2, 3].map(t => renderUpgrade(t))}
                    </div>
                </div>
            </div>
        </div>
    )
}
