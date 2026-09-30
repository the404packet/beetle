import { useState, useEffect, createContext, useContext } from 'react'
import './index.css'
import Sidebar from './components/Sidebar'
import AuditTab from './components/AuditTab'
import HardenTab from './components/HardenTab'

import { ScanSearch, Shield, Camera } from 'lucide-react'
import SnapshotTab from './components/SnapshotTab'

export const TABS = [
  { id: 'audit',    label: 'Audit',     Icon: ScanSearch, Component: AuditTab    },
  { id: 'harden',   label: 'Harden',    Icon: Shield,     Component: HardenTab   },
  { id: 'snapshot', label: 'Snapshots', Icon: Camera,     Component: SnapshotTab },
]

const DEFAULT_MODULES = { audit: [], harden: [], severities: ['basic', 'moderate', 'strong'] }

/* ── Theme context ──────────────────────────────────────────────────────── */
export const ThemeContext = createContext({ dark: false, toggle: () => {} })
export const useTheme = () => useContext(ThemeContext)

export default function App() {
  const [activeTab, setActiveTab] = useState('audit')
  const [modules,   setModules]   = useState(DEFAULT_MODULES)
  const [dark, setDark] = useState(() => {
    try { return localStorage.getItem('beetle-theme') === 'dark' } catch { return false }
  })

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light')
    try { localStorage.setItem('beetle-theme', dark ? 'dark' : 'light') } catch {}
  }, [dark])

  useEffect(() => {
    fetch('/api/modules')
      .then(r => r.json())
      .then(data => setModules({ ...DEFAULT_MODULES, ...data }))
      .catch(() => {})
  }, [])

  const active = TABS.find(t => t.id === activeTab)

  return (
    <ThemeContext.Provider value={{ dark, toggle: () => setDark(d => !d) }}>
      <div style={{
        display: 'flex',
        height: '100vh',
        overflow: 'hidden',
        padding: '14px 16px',
        gap: 12,
        alignItems: 'stretch',
      }}>

        {/* Slim icon sidebar */}
        <Sidebar tabs={TABS} activeTab={activeTab} setActiveTab={setActiveTab} />

        {/* Floating main panel */}
        <div style={{
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
          background: 'var(--panel)',
          border: '1px solid var(--panel-border)',
          borderRadius: 'var(--radius-2xl)',
          backdropFilter: 'blur(24px)',
          WebkitBackdropFilter: 'blur(24px)',
          boxShadow: 'var(--shadow-lg)',
        }}>

          {/* Top bar */}
          <div style={{
            height: 56,
            borderBottom: '1px solid var(--border)',
            display: 'flex', alignItems: 'center',
            padding: '0 28px',
            gap: 10,
            flexShrink: 0,
          }}>
            <active.Icon size={15} color="var(--text-3)" />
            <span style={{ fontSize: 14, fontWeight: 650, color: 'var(--text-1)', letterSpacing: '-.2px' }}>
              {active.label}
            </span>
            <span style={{ fontSize: 12, color: 'var(--text-3)', marginLeft: 2 }}>
              {active.id === 'audit'    && '— Scan system configurations'}
              {active.id === 'harden'   && '— Apply hardening remediation'}
              {active.id === 'snapshot' && '— Capture and manage system snapshots'}
            </span>
          </div>

          {/* Scrollable content */}
          <div style={{ flex: 1, overflowY: 'auto', position: 'relative' }}>
            {/* Watermark */}
            <div style={{
              position: 'absolute',
              bottom: 24,
              right: 24,
              width: 280,
              height: 280,
              backgroundImage: 'url(/static/beetle.png)',
              backgroundSize: 'contain',
              backgroundRepeat: 'no-repeat',
              backgroundPosition: 'center',
              opacity: 0.035,
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
    </ThemeContext.Provider>
  )
}
