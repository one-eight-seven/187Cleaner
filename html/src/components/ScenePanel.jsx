import { useState, useEffect } from 'react'

const TIER_LABELS = { 1: 'T1', 2: 'T2', 3: 'T3' }

function TaskRow({ label, done }) {
    return (
        <div style={{
            display: 'flex', alignItems: 'center', gap: '8px',
            padding: '5px 8px', borderRadius: '6px',
            background: done ? 'rgba(34,197,94,0.08)' : 'rgba(255,255,255,0.03)',
            marginBottom: '3px', transition: 'all 0.2s',
        }}>
            <span style={{
                width: '16px', height: '16px', borderRadius: '4px', flexShrink: 0,
                background: done ? '#22c55e' : 'transparent',
                border: done ? '1px solid #22c55e' : '1px solid rgba(255,255,255,0.2)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: '10px', color: '#fff',
            }}>{done ? '✓' : ''}</span>
            <span style={{ fontSize: '12px', color: done ? '#94a3b8' : '#f1f5f9', textDecoration: done ? 'line-through' : 'none' }}>
                {label}
            </span>
        </div>
    )
}

function Section({ title, icon, items, completed }) {
    if (!items || items.length === 0) return null
    return (
        <div style={{ marginBottom: '10px' }}>
            <div style={{ fontSize: '11px', color: '#8b5cf6', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '5px' }}>
                {icon} {title}
            </div>
            {items.map((_, i) => (
                <TaskRow key={i} label={`${title} ${i + 1}`} done={!!completed[i + 1]} />
            ))}
        </div>
    )
}

export default function ScenePanel({ initialData, liveUpdate }) {
    const [heat, setHeat]   = useState(0)
    const [timer, setTimer] = useState('--:--')
    const [tasks, setTasks] = useState({ bodies: {}, surfaces: {}, evidence: {} })
    const [data]            = useState(initialData)

    useEffect(() => {
        if (!liveUpdate) return
        if (liveUpdate.heat  !== undefined) setHeat(liveUpdate.heat)
        if (liveUpdate.timer !== undefined) setTimer(liveUpdate.timer)
        if (liveUpdate.tasks) setTasks(liveUpdate.tasks)
    }, [liveUpdate])

    const heatColor = heat < 50 ? '#22c55e' : heat < 80 ? '#f59e0b' : '#ef4444'
    const tierBadge = TIER_LABELS[data?.tier] || 'T1'

    return (
        <div className="panel" style={{
            width: '290px', position: 'fixed', top: '20px', left: '20px',
        }}>
            <div className="panel-header" style={{ padding: '12px 14px 10px' }}>
                <div className="panel-title" style={{ fontSize: '14px' }}>
                    <div className="icon">🧹</div>
                    Scene Assessment
                    <span className="badge badge-warning" style={{ fontSize: '10px', padding: '1px 6px' }}>{tierBadge}</span>
                </div>
            </div>

            <div className="panel-body" style={{ padding: '12px 14px' }}>
                {/* Heat gauge */}
                <div style={{ marginBottom: '10px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '4px', fontSize: '11px' }}>
                        <span style={{ color: '#94a3b8' }}>Heat</span>
                        <span style={{ color: heatColor, fontWeight: 600 }}>{heat}%</span>
                    </div>
                    <div className="progress-bar" style={{ height: '5px' }}>
                        <div className="progress-fill" style={{
                            width: `${heat}%`,
                            background: `linear-gradient(90deg, #22c55e, ${heatColor})`,
                        }} />
                    </div>
                </div>

                {/* Timer */}
                <div style={{
                    textAlign: 'center', fontSize: '20px', fontWeight: 700, letterSpacing: '2px',
                    color: '#f1f5f9', marginBottom: '10px', fontVariantNumeric: 'tabular-nums',
                }}>
                    {timer}
                </div>

                <div className="divider" style={{ margin: '8px 0' }} />

                {/* Tasks */}
                <Section title="Bodies"   icon="🗃️" items={data?.tasks?.bodies}   completed={tasks.bodies}   />
                <Section title="Surfaces" icon="🧽" items={data?.tasks?.surfaces} completed={tasks.surfaces} />
                <Section title="Evidence" icon="🔍" items={data?.tasks?.evidence} completed={tasks.evidence} />
            </div>
        </div>
    )
}
