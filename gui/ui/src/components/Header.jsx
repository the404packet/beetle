import { ShieldCheck, ScanSearch, Shield } from 'lucide-react'

function TabBtn({ label, icon: Icon, active, onClick }) {
  return (
    <button
      onClick={onClick}
      style={{
        display: 'flex', alignItems: 'center', gap: 6,
        padding: '6px 14px',
        border: `1px solid ${active ? 'var(--accent-ring)' : 'transparent'}`,
        borderRadius: 'var(--radius-sm)',
        background: active ? 'var(--accent-light)' : 'transparent',
        color: active ? 'var(--accent)' : 'var(--text-2)',
        fontSize: 13, fontWeight: 500,
        transition: 'all var(--transition)',
      }}
    >
      <Icon size={14} />
      {label}
    </button>
  )
}

export default function Header({ tab, setTab }) {
  return (
    <header style={{
      background: 'var(--surface)',
      borderBottom: '1px solid var(--border)',
      position: 'sticky', top: 0, zIndex: 100,
      boxShadow: 'var(--shadow-sm)',
    }}>
      <div style={{
        maxWidth: 1200, margin: '0 auto',
        padding: '0 24px', height: 56,
        display: 'flex', alignItems: 'center',
        justifyContent: 'space-between', gap: 16,
      }}>
        {/* Brand */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{
            width: 32, height: 32,
            background: 'var(--accent)',
            borderRadius: 'var(--radius-sm)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', flexShrink: 0,
          }}>
            <ShieldCheck size={17} />
          </div>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700, lineHeight: 1.1 }}>Beetle</div>
            <div style={{ fontSize: 10.5, color: 'var(--text-3)', letterSpacing: '.3px', textTransform: 'uppercase' }}>
              OS Hardening Framework
            </div>
          </div>
        </div>

        {/* Tabs */}
        <nav style={{ display: 'flex', gap: 3 }}>
          <TabBtn label="Audit"  icon={ScanSearch} active={tab==='audit'}  onClick={() => setTab('audit')}  />
          <TabBtn label="Harden" icon={Shield}     active={tab==='harden'} onClick={() => setTab('harden')} />
        </nav>
      </div>
    </header>
  )
}
