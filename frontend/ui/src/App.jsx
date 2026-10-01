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
  const [cursor, setCursor] = useState({ x: -999, y: -999 })

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light')
    try { localStorage.setItem('beetle-theme', dark ? 'dark' : 'light') } catch {}
  }, [dark])

  /* ── Cursor glow ── */
  useEffect(() => {
    let raf = null
    const onMove = (e) => {
      if (raf) return
      raf = requestAnimationFrame(() => {
        setCursor({ x: e.clientX, y: e.clientY })
        raf = null
      })
    }
    window.addEventListener('mousemove', onMove, { passive: true })
    return () => { window.removeEventListener('mousemove', onMove); if (raf) cancelAnimationFrame(raf) }
  }, [])

  useEffect(() => {
    fetch('/api/modules')
      .then(r => r.json())
      .then(data => setModules({ ...DEFAULT_MODULES, ...data }))
      .catch(() => {})
  }, [])

  const active = TABS.find(t => t.id === activeTab)

  return (
    <ThemeContext.Provider value={{ dark, toggle: () => setDark(d => !d) }}>
      {/* Cursor glow */}
      <div style={{
        position: 'fixed',
        left: cursor.x - 200,
        top:  cursor.y - 200,
        width: 400,
        height: 400,
        borderRadius: '50%',
        background: dark
          ? 'radial-gradient(circle, rgba(122,148,255,0.08) 0%, transparent 70%)'
          : 'radial-gradient(circle, rgba(91,123,248,0.08) 0%, transparent 70%)',
        pointerEvents: 'none',
        zIndex: 9999,
        transition: 'left 80ms ease, top 80ms ease',
        willChange: 'left, top',
      }} />

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

        {/* Floating main panel — liquid glass */}
        <div className="liquid-panel" style={{
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
        }}>

          {/* Top bar */}
          <div style={{
            height: 56,
            borderBottom: '1px solid var(--glass-border-side)',
            display: 'flex', alignItems: 'center',
            padding: '0 28px',
            gap: 10,
            flexShrink: 0,
            position: 'relative',
            zIndex: 2,
            background: 'rgba(255,255,255,0.06)',
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

          {/* Main content wrapper */}
          <div style={{ flex: 1, position: 'relative', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            
            {/* Static Watermark */}
            <div style={{
              position: 'absolute',
              top: '50%',
              left: '50%',
              transform: 'translate(-50%, -50%)',
              width: '65%',
              height: '65%',
              backgroundImage: 'url(/static/beetle.png)',
              backgroundSize: 'contain',
              backgroundRepeat: 'no-repeat',
              backgroundPosition: 'center',
              opacity: 0.025,
              filter: 'grayscale(100%) blur(1px)',
              pointerEvents: 'none',
              zIndex: 0,
            }} />

            {/* Scrollable content */}
            <div style={{ flex: 1, overflowY: 'auto', zIndex: 1 }}>
              <div style={{ maxWidth: 1200, margin: '0 auto', padding: '28px 28px 64px' }}>
                <active.Component modules={modules} />
              </div>
            </div>
          </div>
        </div>
      </div>
    </ThemeContext.Provider>
  )
}
