import { useState, useEffect, useCallback } from 'react'
import {
  Camera, Trash2, RefreshCw, HardDrive, Clock,
  Tag, CheckCircle2, XCircle, LoaderCircle, Archive,
  RotateCcw, X, AlertTriangle,
} from 'lucide-react'
import { Card, CardHead, CardTitle, EmptyState, PageHeader } from './shared'

/* ── Badge ── */
function Badge({ type }) {
  const isBeetle = type?.toLowerCase() === 'beetle'
  return (
    <span style={{
      fontSize: 10, fontWeight: 600, padding: '2px 8px',
      borderRadius: 99,
      background: isBeetle ? 'var(--accent-light)' : 'var(--surface-3)',
      color: isBeetle ? 'var(--accent)' : 'var(--text-3)',
      border: `1px solid ${isBeetle ? 'var(--accent-ring)' : 'var(--border-solid)'}`,
      letterSpacing: '.3px', textTransform: 'uppercase', whiteSpace: 'nowrap',
    }}>
      {type || 'user'}
    </span>
  )
}

/* ── Toast ── */
function Toast({ msg, ok, onDone }) {
  useEffect(() => {
    const t = setTimeout(onDone, 3500)
    return () => clearTimeout(t)
  }, [onDone])
  return (
    <div className="animate-in" style={{
      position: 'fixed', bottom: 28, right: 28, zIndex: 500,
      display: 'flex', alignItems: 'flex-start', gap: 10,
      padding: '12px 18px',
      background: 'var(--surface)',
      border: `1px solid ${ok ? 'var(--green-ring)' : 'var(--red-ring)'}`,
      borderRadius: 'var(--radius-lg)',
      boxShadow: 'var(--shadow-lg)',
      maxWidth: 380,
    }}>
      {ok
        ? <CheckCircle2 size={16} color="var(--green-stroke)" style={{ flexShrink: 0, marginTop: 1 }} />
        : <XCircle      size={16} color="var(--red-stroke)"   style={{ flexShrink: 0, marginTop: 1 }} />
      }
      <span style={{ fontSize: 12.5, color: 'var(--text-2)', whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>{msg}</span>
    </div>
  )
}

/* ── Restore Modal (streaming output) ── */
function RestoreModal({ snap, onClose, onNotify }) {
  const [lines,   setLines]   = useState([])
  const [done,    setDone]    = useState(false)
  const [success, setSuccess] = useState(false)

  useEffect(() => {
    const h = e => { if (e.key === 'Escape' && done) onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [done, onClose])

  useEffect(() => {
    let cancelled = false   // guard against Strict Mode double-invoke

    async function run() {
      try {
        const res = await fetch('/api/snapshots/restore', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ id: snap.id, name: snap.name }),
        })
        const reader = res.body.getReader()
        const dec = new TextDecoder()
        let buf = ''
        while (true) {
          const { done: d, value } = await reader.read()
          if (d || cancelled) break
          buf += dec.decode(value, { stream: true })
          const parts = buf.split('\n')
          buf = parts.pop()
          for (const part of parts) {
            if (!part.trim()) continue
            try {
              const obj = JSON.parse(part)
              if (!cancelled) {
                setLines(l => [...l, obj])
                if (obj.done) {
                  setDone(true)
                  setSuccess(obj.ok)
                  // Fire toast summary so user sees result after closing modal
                  onNotify?.(
                    obj.ok
                      ? `✓ Restored: ${snap.name || snap.id}`
                      : `✗ Restore failed: ${snap.name || snap.id}`,
                    obj.ok
                  )
                }
              }
            } catch {}
          }
        }
      } catch (e) {
        if (!cancelled) {
          setLines(l => [...l, { line: `Error: ${e.message}`, err: true }])
          setDone(true)
          setSuccess(false)
        }
      }
    }

    run()
    return () => { cancelled = true }  // cleanup: cancel on unmount / re-invoke
  }, [snap.id])

  return (
    /* Single element: backdrop + centering flex container */
    <div
      onClick={done ? onClose : undefined}
      style={{
        position: 'fixed', inset: 0, zIndex: 200,
        background: 'rgba(0,0,0,.45)',
        backdropFilter: 'blur(4px)',
        WebkitBackdropFilter: 'blur(4px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 16,
      }}
    >
      {/* Modal panel — stop click propagation so clicks inside don't close */}
      <div
        className="animate-in"
        onClick={e => e.stopPropagation()}
        style={{
          width: 'min(660px, 100%)',
          background: 'var(--surface)',
          border: '1px solid var(--border)',
          borderRadius: 'var(--radius-xl)',
          boxShadow: 'var(--shadow-lg)',
          overflow: 'hidden',
        }}
      >
        {/* Header */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '16px 22px',
          borderBottom: '1px solid var(--border)',
          background: 'var(--surface-2)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{
              width: 30, height: 30, borderRadius: 'var(--radius-sm)',
              background: done
                ? (success ? 'var(--green-bg)' : 'var(--red-bg)')
                : 'var(--accent-light)',
              border: `1px solid ${done ? (success ? 'var(--green-ring)' : 'var(--red-ring)') : 'var(--accent-ring)'}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {!done
                ? <LoaderCircle size={15} className="spin" color="var(--accent)" />
                : success
                  ? <CheckCircle2 size={15} color="var(--green-stroke)" />
                  : <XCircle      size={15} color="var(--red-stroke)"   />
              }
            </div>
            <div>
              <div style={{ fontSize: 14, fontWeight: 650, color: 'var(--text-1)', letterSpacing: '-.1px' }}>
                {done ? (success ? 'Restore complete' : 'Restore failed') : 'Restoring snapshot…'}
              </div>
              <div style={{ fontSize: 11, color: 'var(--text-3)', marginTop: 1 }}>
                {snap.name || snap.id}
              </div>
            </div>
          </div>
          {done && (
            <button onClick={onClose} style={{
              width: 30, height: 30,
              border: '1px solid var(--border-solid)',
              borderRadius: 'var(--radius-sm)',
              background: 'var(--surface)',
              color: 'var(--text-3)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer', transition: 'all var(--transition)',
            }}
              onMouseEnter={e => { e.currentTarget.style.borderColor = 'var(--accent)'; e.currentTarget.style.color = 'var(--accent)' }}
              onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border-solid)'; e.currentTarget.style.color = 'var(--text-3)' }}
            >
              <X size={14} />
            </button>
          )}
        </div>

        {/* Streaming log output */}
        <div style={{
          padding: '14px 18px',
          maxHeight: 340, overflowY: 'auto',
          fontFamily: "'Menlo','Cascadia Code','Consolas',monospace",
          fontSize: 12.5, lineHeight: 1.9,
          background: 'var(--surface-3)',
        }}>
          {lines.length === 0 && (
            <span style={{ color: 'var(--text-3)' }}>Starting restore…</span>
          )}
          {lines.map((l, i) => (
            <div key={i} style={{
              color: l.ok
                ? 'var(--green-stroke)'
                : l.err
                  ? 'var(--red-stroke)'
                  : 'var(--text-2)',
            }}>
              {l.line}
            </div>
          ))}
          {!done && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, color: 'var(--text-3)', marginTop: 4 }}>
              <LoaderCircle size={12} className="spin" />
              <span style={{ fontSize: 12 }}>Running…</span>
            </div>
          )}
        </div>

        {/* Footer */}
        {done && (
          <div style={{
            padding: '12px 18px',
            borderTop: '1px solid var(--border)',
            background: 'var(--surface-2)',
            display: 'flex', alignItems: 'center', gap: 8,
            fontSize: 12.5,
            color: success ? 'var(--green)' : 'var(--red)',
          }}>
            {success
              ? <><CheckCircle2 size={14} color="var(--green-stroke)" /> Restore completed successfully. Press Esc or click outside to close.</>
              : <><AlertTriangle size={14} color="var(--red-stroke)" /> Restore encountered errors. Check the output above.</>
            }
          </div>
        )}
      </div>
    </div>
  )
}

/* ══ MAIN ══════════════════════════════════════════════════════════════════ */
export default function SnapshotTab() {
  const [snapshots,   setSnapshots]   = useState([])
  const [loading,     setLoading]     = useState(false)
  const [capturing,   setCapturing]   = useState(false)
  const [deletingId,  setDeletingId]  = useState(null)
  const [nameInput,   setNameInput]   = useState('')
  const [toast,       setToast]       = useState(null)
  const [storageInfo, setStorageInfo] = useState('')
  const [restoreSnap, setRestoreSnap] = useState(null)   // snap object being restored

  const notify = (msg, ok = true) => setToast({ msg, ok })

  /* ── load ── */
  const loadSnapshots = useCallback(async () => {
    setLoading(true)
    try {
      const r = await fetch('/api/snapshots')
      const d = await r.json()
      setSnapshots((d.snapshots || []).reverse())
    } catch { notify('Failed to load snapshots', false) }
    setLoading(false)
  }, [])

  const loadSize = useCallback(async () => {
    try {
      const r = await fetch('/api/snapshots/size')
      const d = await r.json()
      setStorageInfo(d.output || '')
    } catch {}
  }, [])

  useEffect(() => { loadSnapshots(); loadSize() }, [loadSnapshots, loadSize])

  /* ── capture ── */
  async function capture() {
    setCapturing(true)
    try {
      const r = await fetch('/api/snapshots/capture', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: nameInput.trim() }),
      })
      const d = await r.json()
      if (d.ok) {
        const nameLine = (d.output || '').split('\n').find(l => l.trim().startsWith('Name'))
        const snapName = nameLine ? nameLine.split(':').slice(1).join(':').trim() : null
        notify(snapName ? `✓ Snapshot created: ${snapName}` : '✓ Snapshot created successfully.')
        setNameInput(''); loadSnapshots(); loadSize()
      } else {
        const errLine = (d.output || '').split('\n').find(l => l.includes('[!]')) || 'Capture failed.'
        notify(errLine.replace('[!]', '').trim() || 'Capture failed.', false)
      }
    } catch { notify('Network error — is the backend running?', false) }
    setCapturing(false)
  }

  /* ── delete ── */
  async function deleteSnap(snap) {
    if (!window.confirm(`Delete snapshot "${snap.name || snap.id}"?\nThis cannot be undone.`)) return
    setDeletingId(snap.id)
    try {
      const r = await fetch(`/api/snapshots/${encodeURIComponent(snap.id)}`, { method: 'DELETE' })
      const d = await r.json()
      if (d.ok) {
        notify(`✓ Deleted: ${snap.name || snap.id}`)
        loadSnapshots(); loadSize()
      } else {
        const errLine = (d.output || '').split('\n').find(l => l.includes('[!]')) || 'Delete failed.'
        notify(errLine.replace('[!]', '').trim() || 'Delete failed.', false)
      }
    } catch { notify('Network error — is the backend running?', false) }
    setDeletingId(null)
  }

  const storageLines = storageInfo
    .split('\n').map(l => l.trim())
    .filter(l => l.startsWith('Object Store') || l.startsWith('Manifests'))

  /* ── icon button helper ── */
  const IconBtn = ({ onClick, disabled, title, icon: Icon, color, hoverBg, hoverBorder, hoverColor, spin: doSpin }) => (
    <button
      onClick={onClick}
      disabled={disabled}
      title={title}
      style={{
        width: 30, height: 30,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        border: '1px solid var(--border-solid)',
        borderRadius: 'var(--radius-sm)',
        background: 'transparent',
        color: color || 'var(--text-3)',
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.35 : 1,
        transition: 'all var(--transition)',
        flexShrink: 0,
      }}
      onMouseEnter={e => {
        if (!disabled) {
          e.currentTarget.style.borderColor = hoverBorder || 'var(--accent)'
          e.currentTarget.style.color = hoverColor || 'var(--accent)'
          if (hoverBg) e.currentTarget.style.background = hoverBg
        }
      }}
      onMouseLeave={e => {
        e.currentTarget.style.borderColor = 'var(--border-solid)'
        e.currentTarget.style.color = color || 'var(--text-3)'
        e.currentTarget.style.background = 'transparent'
      }}
    >
      <Icon size={13} style={{ animation: doSpin ? 'spin 1s linear infinite' : 'none' }} />
    </button>
  )

  return (
    <>
      <PageHeader title="Snapshots" description="beetle snapshot capture | ls | rm | restore">
        {/* Name input */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
          <label style={{ fontSize: 10.5, fontWeight: 600, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.7px' }}>
            Snapshot Name
          </label>
          <input
            value={nameInput}
            onChange={e => setNameInput(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter' && !capturing) capture() }}
            placeholder="optional label…"
            style={{
              height: 34, padding: '0 11px',
              background: 'var(--surface)',
              border: '1px solid var(--border-solid)',
              borderRadius: 'var(--radius-sm)',
              color: 'var(--text-1)', fontSize: 13,
              fontFamily: 'inherit', outline: 'none',
              boxShadow: 'var(--shadow-sm)',
              transition: 'border-color var(--transition), box-shadow var(--transition)',
              width: 180,
            }}
            onFocus={e => { e.target.style.borderColor = 'var(--accent)'; e.target.style.boxShadow = '0 0 0 3px var(--accent-ring)' }}
            onBlur={e  => { e.target.style.borderColor = 'var(--border-solid)'; e.target.style.boxShadow = 'var(--shadow-sm)' }}
          />
        </div>

        {/* Capture button */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
          <label style={{ fontSize: 10.5, color: 'transparent', letterSpacing: '.7px' }}>&nbsp;</label>
          <button
            onClick={capture} disabled={capturing}
            style={{
              display: 'inline-flex', alignItems: 'center', gap: 7,
              padding: '7px 18px', border: 'none',
              borderRadius: 'var(--radius-sm)',
              background: 'linear-gradient(135deg, var(--accent) 0%, var(--accent-dark) 100%)',
              color: '#fff', fontSize: 13, fontWeight: 600,
              cursor: capturing ? 'not-allowed' : 'pointer',
              opacity: capturing ? .55 : 1,
              boxShadow: capturing ? 'none' : '0 2px 12px var(--accent-glow)',
              transition: 'opacity var(--transition)',
            }}
          >
            {capturing
              ? <><LoaderCircle size={14} className="spin" />Capturing…</>
              : <><Camera size={14} />Capture Snapshot</>
            }
          </button>
        </div>

        {/* Refresh */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
          <label style={{ fontSize: 10.5, color: 'transparent' }}>&nbsp;</label>
          <button
            onClick={() => { loadSnapshots(); loadSize() }} disabled={loading} title="Refresh"
            style={{
              display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
              width: 34, height: 34,
              border: '1px solid var(--border-solid)', borderRadius: 'var(--radius-sm)',
              background: 'var(--surface)', color: 'var(--text-2)', cursor: 'pointer',
              boxShadow: 'var(--shadow-sm)', transition: 'all var(--transition)',
            }}
            onMouseEnter={e => { e.currentTarget.style.borderColor = 'var(--accent)'; e.currentTarget.style.color = 'var(--accent)' }}
            onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border-solid)'; e.currentTarget.style.color = 'var(--text-2)' }}
          >
            <RefreshCw size={14} style={{ animation: loading ? 'spin 1s linear infinite' : 'none' }} />
          </button>
        </div>
      </PageHeader>

      {/* Storage strip */}
      {storageLines.length > 0 && (
        <div style={{
          display: 'flex', gap: 16, flexWrap: 'wrap', alignItems: 'center',
          padding: '10px 16px', marginBottom: 20,
          background: 'var(--surface)', border: '1px solid var(--border)',
          borderRadius: 'var(--radius-md)', boxShadow: 'var(--shadow-sm)',
        }}>
          <HardDrive size={14} color="var(--text-3)" style={{ flexShrink: 0 }} />
          {storageLines.map((l, i) => (
            <span key={i} style={{ fontSize: 12, color: 'var(--text-2)' }}>{l}</span>
          ))}
        </div>
      )}

      {/* Empty */}
      {!loading && snapshots.length === 0 && (
        <EmptyState icon={Archive} title="No snapshots yet" subtitle="Click" accentWord="Capture Snapshot" />
      )}

      {/* List */}
      {(loading || snapshots.length > 0) && (
        <Card>
          <CardHead>
            <CardTitle icon={Archive}>
              Snapshot List
              {snapshots.length > 0 && (
                <span style={{ marginLeft: 6, fontSize: 11, fontWeight: 700, background: 'var(--surface-3)', color: 'var(--text-3)', borderRadius: 4, padding: '1px 6px' }}>
                  {snapshots.length}
                </span>
              )}
            </CardTitle>
            <div style={{ display: 'grid', gridTemplateColumns: '80px 80px 40px', gap: 4, fontSize: 10.5, color: 'var(--text-3)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '.5px', textAlign: 'center' }}>
              <span>Type</span><span>Actions</span>
            </div>
          </CardHead>

          {loading && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '20px 18px', color: 'var(--text-3)', fontSize: 13 }}>
              <LoaderCircle size={14} className="spin" color="var(--accent)" /> Loading snapshots…
            </div>
          )}

          {snapshots.map((snap, i) => {
            const isBeetle = snap.type?.toLowerCase() === 'beetle'
            return (
              <div
                key={snap.id}
                className="animate-in"
                style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr auto auto auto auto',
                  alignItems: 'center', gap: 12,
                  padding: '13px 18px',
                  borderBottom: i < snapshots.length - 1 ? '1px solid var(--border)' : 'none',
                  transition: 'background var(--transition)',
                }}
                onMouseEnter={e => e.currentTarget.style.background = 'var(--surface-2)'}
                onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
              >
                {/* Name + ID + time */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0 }}>
                  <span style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-1)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {snap.name || snap.id}
                  </span>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    {snap.name && snap.name !== snap.id && (
                      <span style={{ fontSize: 11, color: 'var(--text-3)', fontFamily: 'monospace' }}>
                        {snap.id}
                      </span>
                    )}
                    <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, color: 'var(--text-3)' }}>
                      <Clock size={10} />{snap.created}
                    </span>
                  </div>
                </div>

                {/* Type badge */}
                <Badge type={snap.type} />

                {/* ── Restore button ── */}
                <IconBtn
                  onClick={() => setRestoreSnap(snap)}
                  disabled={false}
                  title="Restore this snapshot"
                  icon={RotateCcw}
                  hoverBorder="var(--accent-ring)"
                  hoverBg="var(--accent-light)"
                  hoverColor="var(--accent)"
                />

                {/* ── Delete button ── */}
                <IconBtn
                  onClick={() => deleteSnap(snap)}
                  disabled={deletingId === snap.id || isBeetle}
                  title={isBeetle ? 'Auto snapshots can only be removed by daemon' : 'Delete snapshot'}
                  icon={deletingId === snap.id ? LoaderCircle : Trash2}
                  spin={deletingId === snap.id}
                  hoverBorder="var(--red-ring)"
                  hoverBg="var(--red-bg)"
                  hoverColor="var(--red-stroke)"
                />
              </div>
            )
          })}
        </Card>
      )}

      {/* Restore modal */}
      {restoreSnap && (
        <RestoreModal
          snap={restoreSnap}
          onClose={() => { setRestoreSnap(null); loadSnapshots(); loadSize() }}
          onNotify={notify}
        />
      )}

      {/* Toast */}
      {toast && <Toast msg={toast.msg} ok={toast.ok} onDone={() => setToast(null)} />}
    </>
  )
}
