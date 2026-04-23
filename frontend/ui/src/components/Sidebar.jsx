import { ShieldCheck } from 'lucide-react'

export default function Sidebar({ tabs, activeTab, setActiveTab }) {
  return (
    <aside style={{
      width: 220,
      flexShrink: 0,
      background: 'var(--surface)',
      borderRight: '1px solid var(--border)',
      display: 'flex',
      flexDirection: 'column',
      height: '100vh',
      boxShadow: '1px 0 0 var(--border)',
    }}>

      {/* Brand */}
      <div style={{
        height: 52,
        borderBottom: '1px solid var(--border)',
        display: 'flex', alignItems: 'center',
        padding: '0 18px', gap: 10,
        flexShrink: 0,
      }}>
        <div style={{
          width: 30, height: 30,
          background: 'var(--accent)',
          borderRadius: 'var(--radius-sm)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#fff', flexShrink: 0,
        }}>
          <ShieldCheck size={16} />
        </div>
        <div>
          <div style={{ fontSize: 14, fontWeight: 700, lineHeight: 1.2 }}>Beetle</div>
          <div style={{ fontSize: 9.5, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.5px' }}>
            Hardening Framework
          </div>
        </div>
      </div>

      {/* Nav section label */}
      <div style={{ padding: '16px 18px 6px' }}>
        <span style={{ fontSize: 10, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.8px' }}>
          Operations
        </span>
      </div>

      {/* Nav items */}
      <nav style={{ flex: 1, padding: '0 10px' }}>
        {tabs.map(tab => {
          const isActive = tab.id === activeTab
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              style={{
                display: 'flex', alignItems: 'center', gap: 9,
                width: '100%', padding: '8px 10px',
                border: `1px solid ${isActive ? 'var(--accent-ring)' : 'transparent'}`,
                borderRadius: 'var(--radius-sm)',
                background: isActive ? 'var(--accent-light)' : 'transparent',
                color: isActive ? 'var(--accent)' : 'var(--text-2)',
                fontSize: 13, fontWeight: isActive ? 600 : 400,
                cursor: 'pointer', textAlign: 'left',
                marginBottom: 2,
                transition: 'all var(--transition)',
              }}
              onMouseEnter={e => { if (!isActive) e.currentTarget.style.background = 'var(--surface-2)' }}
              onMouseLeave={e => { if (!isActive) e.currentTarget.style.background = 'transparent' }}
            >
              {/* Active indicator bar */}
              <span style={{
                width: 3, height: 16, borderRadius: 1, flexShrink: 0,
                background: isActive ? 'var(--accent)' : 'transparent',
                transition: 'background var(--transition)',
              }} />
              <tab.Icon size={14} />
              {tab.label}
            </button>
          )
        })}
      </nav>

      {/* Footer — version */}
      <div style={{
        padding: '14px 18px',
        borderTop: '1px solid var(--border)',
        fontSize: 11, color: 'var(--text-3)',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <img
            src="/static/beetle.png"
            alt="Beetle"
            style={{ width: 18, height: 18, objectFit: 'contain', opacity: .5 }}
          />
          Beetle v1.0.0
        </div>
      </div>
    </aside>
  )
}
