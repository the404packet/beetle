import { useState } from 'react'
import { Shield, Layers, Terminal, CheckCircle2, XCircle, List, LoaderCircle, ChevronDown, AlertTriangle } from 'lucide-react'

async function* streamNDJSON(url, body) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const reader = res.body.getReader()
  const dec = new TextDecoder()
  let buf = ''
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    buf += dec.decode(value, { stream: true })
    const lines = buf.split('\n')
    buf = lines.pop()
    for (const line of lines) {
      if (line.trim()) { try { yield JSON.parse(line) } catch {} }
    }
  }
}

function Card({ children, style = {} }) {
  return (
    <div style={{
      background: 'var(--surface)', border: '1px solid var(--border)',
      borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-sm)',
      overflow: 'hidden', ...style,
    }}>{children}</div>
  )
}

function CardHead({ children }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '12px 16px', borderBottom: '1px solid var(--border)',
      gap: 12, background: 'var(--surface-2)',
    }}>{children}</div>
  )
}

function FormalSelect({ value, onChange, children, label }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      {label && <label style={{ fontSize: 10.5, fontWeight: 600, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.6px' }}>{label}</label>}
      <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'center' }}>
        <select value={value} onChange={e => onChange(e.target.value)} style={{
          appearance: 'none', background: 'var(--surface)',
          border: '1px solid var(--border)', borderRadius: 'var(--radius-sm)',
          color: 'var(--text-1)', fontSize: 13, fontWeight: 500,
          padding: '6px 28px 6px 9px', cursor: 'pointer', outline: 'none',
          fontFamily: 'inherit',
        }}>
          {children}
        </select>
        <ChevronDown size={12} style={{ position: 'absolute', right: 7, pointerEvents: 'none', color: 'var(--text-3)' }} />
      </div>
    </div>
  )
}

function HardenRow({ result }) {
  const ok = result.success
  const stateLabel = ok ? 'SUCCESS' : 'FAILED'
  return (
    <div className="animate-in" style={{
      display: 'grid',
      gridTemplateColumns: '28px 1fr 90px',
      alignItems: 'center', gap: 10,
      padding: '10px 16px',
      borderBottom: '1px solid var(--border)',
    }}>
      <div style={{
        width: 24, height: 24, borderRadius: 'var(--radius-sm)', flexShrink: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: ok ? 'var(--green-bg)' : 'var(--red-bg)',
        color: ok ? 'var(--green)' : 'var(--red)',
      }}>
        {ok ? <CheckCircle2 size={13} /> : <XCircle size={13} />}
      </div>
      <span style={{ fontSize: 13, fontWeight: 400, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        {result.name}
      </span>
      <span style={{
        fontSize: 11, fontWeight: 600, padding: '2px 7px',
        borderRadius: 'var(--radius-sm)', textAlign: 'center',
        background: ok ? 'var(--green-bg)' : 'var(--red-bg)',
        color: ok ? 'var(--green)' : 'var(--red)',
        border: `1px solid ${ok ? 'var(--green-ring)' : 'var(--red-ring)'}`,
        letterSpacing: '.2px',
      }}>
        {stateLabel}
      </span>
    </div>
  )
}

function SummaryFooter({ items }) {
  return (
    <div style={{ display: 'flex', borderTop: '1px solid var(--border)' }}>
      {items.map((it, i) => (
        <div key={it.label} style={{
          flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center',
          padding: '12px 8px', gap: 2,
          borderRight: i < items.length - 1 ? '1px solid var(--border)' : 'none',
        }}>
          <it.icon size={16} color={it.color} />
          <span style={{ fontSize: 18, fontWeight: 700, color: it.color, marginTop: 2 }}>{it.val}</span>
          <span style={{ fontSize: 10.5, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.4px' }}>{it.label}</span>
        </div>
      ))}
    </div>
  )
}

export default function HardenTab({ modules }) {
  const [folder,   setFolder]   = useState('')
  const [severity, setSeverity] = useState('basic')
  const [running,  setRunning]  = useState(false)
  const [results,  setResults]  = useState([])
  const [summary,  setSummary]  = useState(null)
  const [progress, setProgress] = useState(0)

  async function runHarden() {
    setRunning(true); setResults([]); setSummary(null); setProgress(0)
    const all = []
    for await (const obj of streamNDJSON('/api/harden', { folder, severity })) {
      if (obj.type === 'summary') {
        setSummary(obj)
      } else if (obj.type === 'check') {
        all.push(obj)
        setResults([...all])
        setProgress(p => Math.min(p + 2, 93))
      }
    }
    setProgress(100); setRunning(false)
  }

  const succeeded = summary?.succeeded   ?? results.filter(r => r.success).length
  const failed    = summary?.failed_hard ?? results.filter(r => !r.success).length
  const total     = summary?.executed    ?? results.length

  return (
    <>
      {/* Controls */}
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', flexWrap: 'wrap', gap: 16, marginBottom: 20 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 700, letterSpacing: '-.2px' }}>System Hardening</h2>
          <p style={{ fontSize: 12.5, color: 'var(--text-2)', marginTop: 3 }}>
            Runs <code style={{ fontFamily: 'monospace', background: 'var(--surface-2)', border: '1px solid var(--border)', padding: '1px 5px', borderRadius: 'var(--radius-sm)', fontSize: 12 }}>beetle harden [module] [severity]</code>
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, flexWrap: 'wrap' }}>
          <FormalSelect label="Module" value={folder} onChange={setFolder}>
            <option value="">All modules</option>
            {modules.harden.map(f => <option key={f} value={f}>{f.replace(/_/g, ' ')}</option>)}
          </FormalSelect>
          <FormalSelect label="Severity" value={severity} onChange={setSeverity}>
            {modules.severities.map(s => <option key={s} value={s}>{s}</option>)}
          </FormalSelect>
          <button onClick={runHarden} disabled={running} style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '7px 16px', border: 'none',
            borderRadius: 'var(--radius-sm)',
            background: 'var(--accent)', color: '#fff',
            fontSize: 13, fontWeight: 600,
            cursor: running ? 'not-allowed' : 'pointer',
            opacity: running ? .5 : 1,
            letterSpacing: '.1px',
          }}>
            {running ? <LoaderCircle size={14} className="spin" /> : <Shield size={14} />}
            {running ? 'Running…' : (folder ? `Harden: ${folder.replace(/_/g, ' ')}` : 'Harden All')}
          </button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '252px 1fr', gap: 16, alignItems: 'start' }}>

        {/* Module selector */}
        <Card style={{ position: 'sticky', top: 74 }}>
          <CardHead>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontWeight: 600, fontSize: 13 }}>
              <Layers size={14} color="var(--text-3)" />
              Modules
            </div>
          </CardHead>
          <div style={{ padding: '8px' }}>
            {/* All */}
            <div
              onClick={() => setFolder('')}
              style={{
                display: 'flex', alignItems: 'center', gap: 8,
                padding: '8px 10px', borderRadius: 'var(--radius-sm)',
                border: `1px solid ${folder === '' ? 'var(--accent-ring)' : 'transparent'}`,
                background: folder === '' ? 'var(--accent-light)' : 'transparent',
                cursor: 'pointer', marginBottom: 2,
                fontSize: 13, fontWeight: folder === '' ? 600 : 400,
                color: folder === '' ? 'var(--accent)' : 'var(--text-1)',
                transition: 'all var(--transition)',
              }}
            >
              <Shield size={13} color={folder === '' ? 'var(--accent)' : 'var(--text-3)'} />
              All Modules
            </div>

            {/* Divider */}
            <div style={{ height: 1, background: 'var(--border)', margin: '4px 0' }} />

            {modules.harden.map(f => (
              <div
                key={f}
                onClick={() => setFolder(f)}
                style={{
                  display: 'flex', alignItems: 'center', gap: 8,
                  padding: '8px 10px', borderRadius: 'var(--radius-sm)',
                  border: `1px solid ${folder === f ? 'var(--accent-ring)' : 'transparent'}`,
                  background: folder === f ? 'var(--accent-light)' : 'transparent',
                  cursor: 'pointer', marginBottom: 2,
                  fontSize: 13, fontWeight: folder === f ? 600 : 400,
                  color: folder === f ? 'var(--accent)' : 'var(--text-2)',
                  transition: 'all var(--transition)',
                }}
                onMouseEnter={e => { if (folder !== f) e.currentTarget.style.background = 'var(--surface-2)' }}
                onMouseLeave={e => { if (folder !== f) e.currentTarget.style.background = 'transparent' }}
              >
                <span style={{ width: 6, height: 6, borderRadius: '1px', background: folder === f ? 'var(--accent)' : 'var(--border)', flexShrink: 0 }} />
                <span style={{ textTransform: 'capitalize' }}>{f.replace(/_/g, ' ')}</span>
              </div>
            ))}
          </div>
        </Card>

        {/* Output panel */}
        <Card>
          <CardHead>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontWeight: 600, fontSize: 13 }}>
              <Terminal size={14} color="var(--text-3)" />
              Output
            </div>
          </CardHead>

          {!running && results.length === 0 && (
            <div style={{
              textAlign: 'center', padding: '64px 24px', color: 'var(--text-3)',
            }}>
              <Shield size={36} style={{ margin: '0 auto 12px', display: 'block', opacity: .35 }} />
              <p style={{ fontSize: 13 }}>Select a module and click <strong style={{ color: 'var(--text-2)' }}>Harden</strong>.</p>
            </div>
          )}

          {running && (
            <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--border)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 8, fontSize: 12.5, color: 'var(--text-2)', fontWeight: 500 }}>
                <LoaderCircle size={13} color="var(--accent)" className="spin" />
                Running… {results.length} scripts done
              </div>
              <div style={{ height: 4, background: 'var(--surface-2)', borderRadius: 1, overflow: 'hidden' }}>
                <div style={{ height: '100%', background: 'var(--accent)', width: `${progress}%`, transition: 'width 400ms ease' }} />
              </div>
            </div>
          )}

          {results.length > 0 && (
            <div style={{ maxHeight: 500, overflowY: 'auto' }}>
              {results.map((r, i) => <HardenRow key={i} result={r} />)}
            </div>
          )}

          {summary && (
            <SummaryFooter items={[
              { icon: CheckCircle2,  label: 'Succeeded', val: succeeded, color: 'var(--green)' },
              { icon: XCircle,       label: 'Failed',    val: failed,    color: 'var(--red)'   },
              { icon: AlertTriangle, label: 'Skipped',   val: summary.skipped ?? 0, color: 'var(--text-3)' },
              { icon: List,          label: 'Total',     val: total,     color: 'var(--text-3)' },
            ]} />
          )}
        </Card>
      </div>
    </>
  )
}
