import { useEffect } from 'react'
import { X, CheckCircle2, XCircle } from 'lucide-react'

export default function ResultModal({ result, mode = 'audit', onClose }) {
  const pass = mode === 'audit' ? result.hardened : result.success

  useEffect(() => {
    const h = e => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])

  return (
    <>
      {/* Backdrop */}
      <div onClick={onClose} style={{
        position: 'fixed', inset: 0,
        background: 'rgba(10,12,28,.50)',
        backdropFilter: 'blur(6px)',
        WebkitBackdropFilter: 'blur(6px)',
        zIndex: 200,
        animation: 'fadeSlide 150ms ease',
      }} />

      {/* Modal */}
      <div className="animate-in" style={{
        position: 'fixed',
        top: '50%', left: '50%',
        transform: 'translate(-50%, -50%)',
        width: 'min(640px, calc(100vw - 32px))',
        background: 'var(--surface)',
        border: '1px solid var(--border)',
        borderRadius: 'var(--radius-xl)',
        boxShadow: 'var(--shadow-lg)',
        zIndex: 201,
        overflow: 'hidden',
      }}>
        {/* Header */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '18px 22px',
          borderBottom: '1px solid var(--border)',
          background: 'var(--surface-2)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{
              width: 30, height: 30,
              borderRadius: 'var(--radius-sm)',
              background: pass ? 'var(--green-bg)' : 'var(--red-bg)',
              border: `1px solid ${pass ? 'var(--green-ring)' : 'var(--red-ring)'}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {pass
                ? <CheckCircle2 size={16} color="var(--green-stroke)" />
                : <XCircle      size={16} color="var(--red-stroke)"   />
              }
            </div>
            <h3 style={{ fontSize: 14, fontWeight: 650, color: 'var(--text-1)', letterSpacing: '-.1px' }}>{result.name}</h3>
          </div>
          <button onClick={onClose} style={{
            width: 30, height: 30,
            border: '1px solid var(--border-solid)',
            borderRadius: 'var(--radius-sm)',
            background: 'var(--surface)',
            color: 'var(--text-3)',
            display: 'flex', alignItems: 'center',
            justifyContent: 'center', cursor: 'pointer',
            transition: 'all var(--transition)',
          }}
            onMouseEnter={e => { e.currentTarget.style.borderColor = 'var(--accent)'; e.currentTarget.style.color = 'var(--accent)'; e.currentTarget.style.background = 'var(--accent-light)' }}
            onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border-solid)'; e.currentTarget.style.color = 'var(--text-3)'; e.currentTarget.style.background = 'var(--surface)' }}
          >
            <X size={14} />
          </button>
        </div>

        {/* Body */}
        <div style={{ padding: 22 }}>
          {/* Tags */}
          <div style={{ display: 'flex', gap: 6, marginBottom: 16, flexWrap: 'wrap' }}>
            {[result.status, result.state].filter(Boolean).map(tag => (
              <span key={tag} style={{
                fontSize: 11, fontWeight: 500,
                background: 'var(--surface-2)', color: 'var(--text-2)',
                border: '1px solid var(--border-solid)', borderRadius: 99, padding: '4px 11px',
                letterSpacing: '.2px',
              }}>{tag}</span>
            ))}
          </div>

          {/* Raw output — terminal style */}
          <div style={{
            background: 'var(--surface-3)',
            border: '1px solid var(--border-solid)',
            borderRadius: 'var(--radius-md)', padding: '14px 16px',
            fontFamily: "'Menlo','Cascadia Code','Consolas',monospace",
            fontSize: 12.5, lineHeight: 1.8,
            color: 'var(--text-2)', whiteSpace: 'pre-wrap',
            wordBreak: 'break-all', maxHeight: 280, overflowY: 'auto',
          }}>
            {result.raw || '(no output)'}
          </div>
        </div>
      </div>
    </>
  )
}
