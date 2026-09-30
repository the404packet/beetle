import { ShieldCheck, Sun, Moon } from 'lucide-react'
import { useTheme } from '../App'

export default function Sidebar({ tabs, activeTab, setActiveTab }) {
  const { dark, toggle } = useTheme()

  return (
    <aside style={{
      width: 200,
      flexShrink: 0,
      background: 'var(--sb-bg)',
      border: '1px solid var(--sb-border)',
      borderRadius: 'var(--radius-2xl)',
      display: 'flex',
      flexDirection: 'column',
      padding: '14px 10px',
      gap: 0,
      boxShadow: 'var(--shadow-md)',
      transition: 'background 300ms ease, border-color 300ms ease',
    }}>

      {/* Brand */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '4px 8px 18px',
        borderBottom: '1px solid var(--sb-border)',
        marginBottom: 12,
      }}>
        <div style={{
          width: 32, height: 32,
          background: 'linear-gradient(135deg, #5b7bf8 0%, #7c5ffc 100%)',
          borderRadius: 10,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#fff', flexShrink: 0,
          boxShadow: '0 3px 12px rgba(91,123,248,0.38)',
        }}>
          <ShieldCheck size={16} />
        </div>
        <div>
          <div style={{ fontSize: 14, fontWeight: 700, letterSpacing: '-.2px', color: 'var(--text-1)', lineHeight: 1.2 }}>
            Beetle
          </div>
          <div style={{ fontSize: 9.5, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.6px' }}>
            Hardening
          </div>
        </div>
      </div>

      {/* Section label */}
      <div style={{ padding: '0 8px 6px' }}>
        <span style={{ fontSize: 9.5, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '1px' }}>
          Operations
        </span>
      </div>

      {/* Nav items */}
      <nav style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
        {tabs.map(tab => {
          const isActive = tab.id === activeTab
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              style={{
                display: 'flex', alignItems: 'center', gap: 9,
                width: '100%', padding: '9px 10px',
                border: `1px solid ${isActive ? 'var(--accent-ring)' : 'transparent'}`,
                borderRadius: 'var(--radius-md)',
                background: isActive ? 'var(--sb-active-bg)' : 'transparent',
                color: isActive ? 'var(--sb-active-text)' : 'var(--sb-text)',
                fontSize: 13, fontWeight: isActive ? 600 : 400,
                cursor: 'pointer', textAlign: 'left',
                transition: 'all var(--transition)',
                position: 'relative',
              }}
              onMouseEnter={e => { if (!isActive) { e.currentTarget.style.background = 'var(--sb-hover-bg)'; e.currentTarget.style.color = 'var(--sb-icon-hover)' } }}
              onMouseLeave={e => { if (!isActive) { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = 'var(--sb-text)' } }}
            >
              {/* Active left bar */}
              <span style={{
                width: 3, height: 16, borderRadius: 2, flexShrink: 0,
                background: isActive ? 'var(--accent)' : 'transparent',
                boxShadow: isActive ? '0 0 6px var(--accent-glow)' : 'none',
                transition: 'all var(--transition)',
              }} />
              <tab.Icon size={15} color={isActive ? 'var(--accent)' : 'var(--sb-icon)'} />
              <span>{tab.label}</span>
            </button>
          )
        })}
      </nav>

      {/* Footer */}
      <div style={{
        borderTop: '1px solid var(--sb-border)',
        paddingTop: 10,
        marginTop: 4,
        display: 'flex', flexDirection: 'column', gap: 6,
      }}>
        {/* Dark mode toggle */}
        <button
          onClick={toggle}
          style={{
            display: 'flex', alignItems: 'center', gap: 9,
            width: '100%', padding: '9px 10px',
            border: '1px solid transparent',
            borderRadius: 'var(--radius-md)',
            background: 'transparent',
            color: 'var(--sb-text)',
            fontSize: 13, fontWeight: 400,
            cursor: 'pointer', textAlign: 'left',
            transition: 'all var(--transition)',
          }}
          onMouseEnter={e => { e.currentTarget.style.background = 'var(--sb-hover-bg)'; e.currentTarget.style.color = 'var(--sb-icon-hover)' }}
          onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = 'var(--sb-text)' }}
        >
          <span style={{ width: 3, flexShrink: 0 }} />
          {dark
            ? <><Sun  size={15} color="#f4c24b" /><span style={{ color: 'var(--sb-text)' }}>Light Mode</span></>
            : <><Moon size={15} /><span>Dark Mode</span></>
          }
        </button>

        {/* Version */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          padding: '4px 10px',
          fontSize: 11, color: 'var(--text-3)',
        }}>
          <img src="/static/beetle.png" alt="" style={{ width: 14, height: 14, objectFit: 'contain', opacity: .35 }} />
          Beetle v1.0.0
        </div>
      </div>
    </aside>
  )
}
