import { useState, useEffect, useCallback } from 'react'
import ContractNotification from './components/ContractNotification'
import ScenePanel from './components/ScenePanel'
import EvidenceModal from './components/EvidenceModal'
import WitnessModal from './components/WitnessModal'
import UpgradeShop from './components/UpgradeShop'
import StatsPanel from './components/StatsPanel'
import BrokerPanel from './components/BrokerPanel'
import PayoutScreen from './components/PayoutScreen'

function App() {
    const [contract, setContract]     = useState(null)
    const [scene, setScene]           = useState(null)
    const [sceneUpdate, setSceneUpdate] = useState(null)
    const [evidence, setEvidence]     = useState(null)
    const [witness, setWitness]       = useState(null)
    const [shopData, setShopData]     = useState(null)
    const [statsData, setStatsData]   = useState(null)
    const [brokerData, setBrokerData] = useState(null)
    const [payout, setPayout]         = useState(null)

    useEffect(() => {
        const handleMessage = (event) => {
            const { action, data } = event.data
            switch (action) {
                case 'showContract':    setContract(data);   break
                case 'hideContract':   setContract(null);   break
                case 'showScene':      setScene(data);      break
                case 'hideScene':      setScene(null);      break
                case 'updateScene':    setSceneUpdate(data); break
                case 'showEvidenceDecision': setEvidence(data); break
                case 'hideEvidence':   setEvidence(null);   break
                case 'showWitness':    setWitness(data);    break
                case 'hideWitness':    setWitness(null);    break
                case 'openShop':       setShopData(data);   break
                case 'hideShop':       setShopData(null);   break
                case 'updateShop':     setShopData(d => d ? { ...d, ...data } : null); break
                case 'openStats':      setStatsData(data);  break
                case 'hideStats':      setStatsData(null);  break
                case 'openBroker':     setBrokerData(data); break
                case 'hideBroker':     setBrokerData(null); break
                case 'brokerItemSold': setBrokerData(d => d ? { ...d, evidence: d.evidence.filter(e => e.id !== data.id) } : null); break
                case 'showPayout':     setPayout(data);     break
                case 'hidePayout':     setPayout(null);     break
                default: break
            }
        }
        window.addEventListener('message', handleMessage)
        return () => window.removeEventListener('message', handleMessage)
    }, [])

    const closeEvidence = useCallback((decision) => {
        setEvidence(null)
    }, [])

    const closeWitness = useCallback(() => {
        setWitness(null)
    }, [])

    const closeShop = useCallback(() => {
        S187.post('closeShop')
        setShopData(null)
    }, [])

    const closeStats = useCallback(() => {
        S187.post('closeStats')
        setStatsData(null)
    }, [])

    const closeBroker = useCallback(() => {
        S187.post('closeBroker')
        setBrokerData(null)
    }, [])

    return (
        <>
            {contract && <ContractNotification data={contract} />}

            {scene && (
                <ScenePanel
                    initialData={scene}
                    liveUpdate={sceneUpdate}
                />
            )}

            {evidence && (
                <EvidenceModal
                    data={evidence}
                    onClose={closeEvidence}
                />
            )}

            {witness && (
                <WitnessModal
                    data={witness}
                    onClose={closeWitness}
                />
            )}

            {shopData && (
                <UpgradeShop
                    data={shopData}
                    onClose={closeShop}
                />
            )}

            {statsData && (
                <StatsPanel
                    data={statsData}
                    onClose={closeStats}
                />
            )}

            {brokerData && (
                <BrokerPanel
                    data={brokerData}
                    onClose={closeBroker}
                />
            )}

            {payout && <PayoutScreen data={payout} />}
        </>
    )
}

export default App
