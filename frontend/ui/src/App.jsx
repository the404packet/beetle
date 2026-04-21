import { useState, useEffect } from 'react'
import './index.css'
import Sidebar from './components/Sidebar'
import AuditTab from './components/AuditTab'
import HardenTab from './components/HardenTab'

/* ── Tab registry — add new tabs here ─────────────────────────────────────
   Each entry needs: id, label, icon (lucide name string), component
   The Sidebar will automatically render them.
───────────────────────────────────────────────────────────────────────── */
import { ScanSearch, Shield } from 'lucide-react'

export const TABS = [
  { id: 'audit',  label: 'Audit',  Icon: ScanSearch, Component: AuditTab  },
  { id: 'harden', label: 'Harden', Icon: Shield,     Component: HardenTab },
  // Add new tabs here ↓
]

const DEFAULT_MODULES = { audit: [], harden: [], severities: ['basic', 'moderate', 'strong'] }

export default function App() {
  const [activeTab, setActiveTab] = useState('audit')
  const [modules,   setModules]   = useState(DEFAULT_MODULES)

  useEffect(() => {
    fetch('/api/modules')
      .then(r => r.json())
      .then(data => setModules({ ...DEFAULT_MODULES, ...data }))
      .catch(() => {})
  }, [])

  const active = TABS.find(t => t.id === activeTab)

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden' }}>
      <Sidebar tabs={TABS} activeTab={activeTab} setActiveTab={setActiveTab} />

      {/* Main content area */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>

        {/* Top bar */}
        <div style={{
          height: 52,
          borderBottom: '1px solid var(--border)',
          background: 'var(--surface)',
          display: 'flex', alignItems: 'center',
          padding: '0 28px',
          gap: 10,
          flexShrink: 0,
          boxShadow: 'var(--shadow-sm)',
        }}>
          <active.Icon size={16} color="var(--text-3)" />
          <span style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-1)' }}>{active.label}</span>
          <span style={{ fontSize: 12, color: 'var(--text-3)', marginLeft: 2 }}>
            {active.id === 'audit'  && '— Scan system configurations'}
            {active.id === 'harden' && '— Apply hardening remediation'}
          </span>
        </div>

        {/* Scrollable content with watermark */}
        <div style={{
          flex: 1,
          overflowY: 'auto',
          position: 'relative',
        }}>
          {/* Watermark */}
          <div style={{
            position: 'fixed',
            bottom: 32,
            right: 32,
            width: 320,
            height: 320,
            backgroundImage: 'url(/static/beetle.png)',
            backgroundSize: 'contain',
            backgroundRepeat: 'no-repeat',
            backgroundPosition: 'center',
            opacity: 0.04,
            pointerEvents: 'none',
            zIndex: 0,
          }} />

          {/* Page content */}
          <div style={{ position: 'relative', zIndex: 1, maxWidth: 1200, margin: '0 auto', padding: '28px 28px 64px' }}>
            <active.Component modules={modules} />
          </div>
        </div>
      </div>
    </div>
  )
}
