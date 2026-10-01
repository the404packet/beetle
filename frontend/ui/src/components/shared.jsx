/**
 * shared.jsx — shared UI primitives used by AuditTab and HardenTab
 */
import { ChevronDown, LoaderCircle, CheckCircle2, XCircle } from 'lucide-react'

/* ── Card ─────────────────────────────────────────────────────────────────── */
export function Card({ children, style = {} }) {
  return (
    <div className="glass-card" style={{
      boxShadow: 'var(--shadow-card)',
      overflow: 'hidden',
      ...style,
    }}>
      {children}
    </div>
  )
}

/* ── CardHead ─────────────────────────────────────────────────────────────── */
export function CardHead({ children }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '13px 18px',
      borderBottom: '1px solid var(--glass-border-side)',
      gap: 12, flexWrap: 'wrap',
      background: 'rgba(255,255,255,0.06)',
      position: 'relative', zIndex: 1,
    }}>
      {children}
    </div>
  )
}

/* ── CardTitle ────────────────────────────────────────────────────────────── */
export function CardTitle({ icon: Icon, children }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 7,
      fontWeight: 600, fontSize: 13, letterSpacing: '-.1px', color: 'var(--text-1)',
    }}>
      <Icon size={14} color="var(--text-3)" />
      {children}
    </div>
  )
}

/* ── Select ───────────────────────────────────────────────────────────────── */
export function Select({ value, onChange, children, label }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      {label && (
        <label style={{
          fontSize: 10.5, fontWeight: 600, color: 'var(--text-3)',
          textTransform: 'uppercase', letterSpacing: '.7px',
        }}>
          {label}
        </label>
      )}
      <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'center' }}>
        <select
          value={value}
          onChange={e => onChange(e.target.value)}
          style={{
            appearance: 'none',
            background: 'var(--glass-bg)',
            backdropFilter: 'blur(12px)',
            WebkitBackdropFilter: 'blur(12px)',
            border: '1px solid var(--glass-border-side)',
            borderTop: '1px solid var(--glass-border-top)',
            borderRadius: 'var(--radius-sm)',
            color: 'var(--text-1)', fontSize: 13, fontWeight: 500,
            padding: '7px 30px 7px 11px', cursor: 'pointer', outline: 'none',
            fontFamily: 'inherit',
            transition: 'border-color var(--transition), box-shadow var(--transition)',
            boxShadow: 'var(--shadow-sm)',
          }}
          onFocus={e => {
            e.target.style.borderColor = 'var(--accent)'
            e.target.style.boxShadow = '0 0 0 3px var(--accent-ring)'
          }}
          onBlur={e => {
            e.target.style.borderColor = 'var(--border-solid)'
            e.target.style.boxShadow = 'var(--shadow-sm)'
          }}
        >
          {children}
        </select>
        <ChevronDown size={12} style={{ position: 'absolute', right: 9, pointerEvents: 'none', color: 'var(--text-3)' }} />
      </div>
    </div>
  )
}

/* ── PrimaryBtn ───────────────────────────────────────────────────────────── */
export function PrimaryBtn({ onClick, disabled, loading, icon: Icon, label }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 7,
        padding: '8px 18px', border: 'none',
        borderRadius: 'var(--radius-sm)',
        background: 'linear-gradient(135deg, var(--accent) 0%, var(--accent-dark) 100%)',
        color: '#fff',
        fontSize: 13, fontWeight: 600,
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? .55 : 1,
        letterSpacing: '.1px',
        boxShadow: disabled ? 'none' : '0 2px 12px var(--accent-glow)',
        transition: 'opacity var(--transition), box-shadow var(--transition)',
      }}
    >
      {loading ? <LoaderCircle size={14} className="spin" /> : <Icon size={14} />}
      {label}
    </button>
  )
}

/* ── FilterTab ────────────────────────────────────────────────────────────── */
export function FilterTab({ active, label, color, count, onClick }) {
  return (
    <button
      onClick={onClick}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 5,
        padding: '4px 11px',
        border: `1px solid ${active ? 'var(--accent-ring)' : 'var(--glass-border-side)'}`,
        borderTop: `1px solid ${active ? 'var(--accent-ring)' : 'var(--glass-border-top)'}`,
        borderRadius: 'var(--radius-sm)',
        background: active ? 'var(--accent-light)' : 'var(--glass-bg)',
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
        color: active ? 'var(--accent)' : 'var(--text-2)',
        fontSize: 12, fontWeight: 500, cursor: 'pointer',
        transition: 'all var(--transition)',
        boxShadow: 'var(--shadow-sm)',
      }}
    >
      {color && (
        <span style={{
          width: 6, height: 6, borderRadius: '2px',
          background: active ? 'var(--accent)' : color,
          display: 'inline-block', flexShrink: 0,
        }} />
      )}
      {label}
      {count != null && (
        <span style={{
          fontSize: 11, fontWeight: 700,
          background: active ? 'var(--accent)' : 'var(--surface-3)',
          color: active ? '#fff' : 'var(--text-3)',
          borderRadius: '4px', padding: '0 5px', lineHeight: '18px',
        }}>
          {count}
        </span>
      )}
    </button>
  )
}

/* ── ResultRow ────────────────────────────────────────────────────────────── */
/**
 * pass      — boolean: true = green (hardened/success), false = red
 * name      — string
 * badgeText — e.g. "HARDENED" / "NOT HARDENED" / "SUCCESS" / "FAILED"
 * onClick   — optional click handler
 */
export function ResultRow({ pass, name, badgeText, onClick }) {
  const Icon = pass ? CheckCircle2 : XCircle

  return (
    <div
      className="animate-in"
      onClick={onClick}
      style={{
        display: 'grid',
        gridTemplateColumns: '32px 1fr 128px',
        alignItems: 'center', gap: 12,
        padding: '11px 18px',
        borderBottom: '1px solid var(--border)',
        cursor: onClick ? 'pointer' : 'default',
        transition: 'background var(--transition)',
      }}
      onMouseEnter={e => { if (onClick) e.currentTarget.style.background = 'var(--surface-2)' }}
      onMouseLeave={e => { if (onClick) e.currentTarget.style.background = 'transparent' }}
    >
      {/* Status icon */}
      <div style={{
        width: 26, height: 26,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: pass ? 'var(--green-bg)' : 'var(--red-bg)',
        color: pass ? 'var(--green-stroke)' : 'var(--red-stroke)',
        borderRadius: 'var(--radius-sm)',
        border: `1px solid ${pass ? 'var(--green-ring)' : 'var(--red-ring)'}`,
        flexShrink: 0,
      }}>
        <Icon size={13} />
      </div>

      {/* Name */}
      <span style={{
        fontSize: 13, fontWeight: 400, color: 'var(--text-1)',
        overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
      }}>
        {name}
      </span>

      {/* Badge */}
      <span style={{
        display: 'inline-block',
        fontSize: 11, fontWeight: 600,
        padding: '3px 8px',
        borderRadius: 'var(--radius-sm)',
        textAlign: 'center',
        background: pass ? 'var(--green-bg)' : 'var(--red-bg)',
        color: pass ? 'var(--green)' : 'var(--red)',
        border: `1px solid ${pass ? 'var(--green-ring)' : 'var(--red-ring)'}`,
        letterSpacing: '.3px',
      }}>
        {badgeText}
      </span>
    </div>
  )
}

/* ── ProgressStrip ────────────────────────────────────────────────────────── */
export function ProgressStrip({ label, pct }) {
  return (
    <div style={{ padding: '13px 18px', borderBottom: '1px solid var(--border)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 8, fontSize: 12.5, color: 'var(--text-2)', fontWeight: 500 }}>
        <LoaderCircle size={13} color="var(--accent)" className="spin" />
        {label}
      </div>
      <div style={{ height: 4, background: 'var(--surface-3)', borderRadius: 4, overflow: 'hidden' }}>
        <div style={{
          height: '100%',
          background: 'linear-gradient(90deg, var(--accent), var(--accent-dark))',
          width: `${pct}%`,
          transition: 'width 400ms ease',
          borderRadius: 4,
        }} />
      </div>
    </div>
  )
}

/* ── SummaryFooter ────────────────────────────────────────────────────────── */
export function SummaryFooter({ items }) {
  return (
    <div style={{ display: 'flex', borderTop: '1px solid var(--border)', background: 'var(--surface-2)' }}>
      {items.map((it, i) => (
        <div key={it.label} style={{
          flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center',
          padding: '14px 8px', gap: 3,
          borderRight: i < items.length - 1 ? '1px solid var(--border)' : 'none',
        }}>
          <it.icon size={15} color={it.color} />
          <span style={{ fontSize: 20, fontWeight: 700, color: it.color, marginTop: 2, letterSpacing: '-1px' }}>{it.val}</span>
          <span style={{ fontSize: 10, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.5px' }}>{it.label}</span>
        </div>
      ))}
    </div>
  )
}

/* ── EmptyState ───────────────────────────────────────────────────────────── */
export function EmptyState({ icon: Icon, title, subtitle, accentWord }) {
  return (
    <div className="glass-card" style={{
      textAlign: 'center', padding: '80px 24px', color: 'var(--text-3)',
      border: '1.5px dashed var(--glass-border-side)',
      boxShadow: 'var(--shadow-sm)',
    }}>
      <div style={{
        width: 56, height: 56,
        background: 'var(--glass-bg)',
        backdropFilter: 'blur(12px)',
        borderRadius: 16,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        margin: '0 auto 16px',
        border: '1px solid var(--glass-border-side)',
        borderTop: '1px solid var(--glass-border-top)',
        position: 'relative', zIndex: 1,
      }}>
        <Icon size={24} color="var(--text-3)" />
      </div>
      <p style={{ fontSize: 14, fontWeight: 500, color: 'var(--text-2)', position: 'relative', zIndex: 1 }}>{title}</p>
      <p style={{ fontSize: 12.5, marginTop: 5, position: 'relative', zIndex: 1 }}>
        {subtitle} <strong style={{ color: 'var(--accent)' }}>{accentWord}</strong>.
      </p>
    </div>
  )
}

/* ── PageHeader ───────────────────────────────────────────────────────────── */
export function PageHeader({ title, description, children }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between',
      flexWrap: 'wrap', gap: 16, marginBottom: 24,
    }}>
      <div>
        <h2 style={{ fontSize: 20, fontWeight: 750, letterSpacing: '-.4px', color: 'var(--text-1)' }}>
          {title}
        </h2>
        <p style={{ fontSize: 12.5, color: 'var(--text-3)', marginTop: 4 }}>
          {description && <>Runs <code style={{
            fontFamily: 'monospace',
            background: 'var(--surface)',
            border: '1px solid var(--border-solid)',
            padding: '2px 6px', borderRadius: 6, fontSize: 12, color: 'var(--accent)',
          }}>{description}</code></>}
        </p>
      </div>
      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, flexWrap: 'wrap' }}>
        {children}
      </div>
    </div>
  )
}
