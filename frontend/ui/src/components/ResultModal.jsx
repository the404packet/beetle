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
      <div onClick={onClose} style={{
        position: 'fixed', inset: 0,
        background: 'rgba(0,0,0,.22)',
        backdropFilter: 'blur(2px)',
        zIndex: 200,
      }} />
      <div style={{
        position: 'fixed',
        top: '50%', left: '50%',
        transform: 'translate(-50%, -50%)',
        width: 'min(620px, calc(100vw - 32px))',
        background: 'var(--surface)',
        border: '1px solid var(--border)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-lg)',
        zIndex: 201,
      }}>
        {/* Header */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '16px 20px', borderBottom: '1px solid var(--border)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            {pass
              ? <CheckCircle2 size={17} color="var(--green)" />
              : <XCircle      size={17} color="var(--red)"   />
            }
            <h3 style={{ fontSize: 14, fontWeight: 600 }}>{result.name}</h3>
          </div>
          <button onClick={onClose} style={{
            width: 28, height: 28, border: '1px solid var(--border)',
            borderRadius: 'var(--radius-sm)', background: 'var(--surface)',
            color: 'var(--text-2)', display: 'flex', alignItems: 'center',
            justifyContent: 'center', cursor: 'pointer',
          }}>
            <X size={14} />
          </button>
        </div>

        {/* Body */}
        <div style={{ padding: 20 }}>
          {/* Tags */}
          <div style={{ display: 'flex', gap: 8, marginBottom: 14, flexWrap: 'wrap' }}>
            {[result.status, result.state].filter(Boolean).map(tag => (
              <span key={tag} style={{
                fontSize: 11, fontWeight: 500,
                background: 'var(--surface-2)', color: 'var(--text-2)',
                border: '1px solid var(--border)', borderRadius: 99, padding: '3px 10px',
              }}>{tag}</span>
            ))}
          </div>

          {/* Raw output */}
          <div style={{
            background: '#f8f9fc', border: '1px solid var(--border)',
            borderRadius: 'var(--radius-md)', padding: 14,
            fontFamily: "'Menlo','Consolas',monospace",
            fontSize: 12.5, lineHeight: 1.7,
            color: 'var(--text-2)', whiteSpace: 'pre-wrap',
            wordBreak: 'break-all', maxHeight: 260, overflowY: 'auto',
          }}>
            {result.raw || '(no output)'}
          </div>
        </div>
      </div>
    </>
  )
}
