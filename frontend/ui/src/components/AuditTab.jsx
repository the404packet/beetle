import { useState } from 'react'
import { ScanSearch, PieChart, ListChecks, CheckCircle2, XCircle, ChevronDown, List, LoaderCircle, AlertTriangle } from 'lucide-react'
import DonutChart from './DonutChart'
import ResultModal from './ResultModal'

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

/* ── Primitives ── */
function Card({ children, style = {} }) {
  return (
    <div style={{
      background: 'var(--surface)',
      border: '1px solid var(--border)',
      borderRadius: 'var(--radius-lg)',
      boxShadow: 'var(--shadow-sm)',
      overflow: 'hidden', ...style,
    }}>{children}</div>
  )
}

function CardHead({ children }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '12px 16px',
      borderBottom: '1px solid var(--border)',
      gap: 12, flexWrap: 'wrap',
      background: 'var(--surface-2)',
    }}>{children}</div>
  )
}

function CardTitle({ icon: Icon, children }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontWeight: 600, fontSize: 13, letterSpacing: '.1px' }}>
      <Icon size={14} color="var(--text-3)" />{children}
    </div>
  )
}

function FormalSelect({ value, onChange, children, label }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      {label && (
        <label style={{ fontSize: 10.5, fontWeight: 600, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.6px' }}>
          {label}
        </label>
      )}
      <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'center' }}>
        <select value={value} onChange={e => onChange(e.target.value)} style={{
          appearance: 'none',
          background: 'var(--surface)', border: '1px solid var(--border)',
          borderRadius: 'var(--radius-sm)',
          color: 'var(--text-1)', fontSize: 13, fontWeight: 500,
          padding: '6px 28px 6px 9px', cursor: 'pointer', outline: 'none',
          fontFamily: 'inherit',
          transition: 'border-color var(--transition)',
        }}
          onFocus={e => e.target.style.borderColor = 'var(--accent)'}
          onBlur={e  => e.target.style.borderColor = 'var(--border)'}
        >
          {children}
        </select>
        <ChevronDown size={12} style={{ position: 'absolute', right: 7, pointerEvents: 'none', color: 'var(--text-3)' }} />
      </div>
    </div>
  )
}

function PrimaryBtn({ onClick, disabled, loading, icon: Icon, label }) {
  return (
    <button onClick={onClick} disabled={disabled} style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '7px 16px', border: 'none',
      borderRadius: 'var(--radius-sm)',
      background: 'var(--accent)', color: '#fff',
      fontSize: 13, fontWeight: 600,
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? .5 : 1,
      letterSpacing: '.1px',
    }}>
      {loading ? <LoaderCircle size={14} className="spin" /> : <Icon size={14} />}
      {label}
    </button>
  )
}

/* Square filter tab — NOT pills */
function FilterTab({ active, label, color, count, onClick }) {
  return (
    <button onClick={onClick} style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '4px 10px',
      border: `1px solid ${active ? 'var(--accent)' : 'var(--border)'}`,
      borderRadius: 'var(--radius-sm)',
      background: active ? 'var(--accent)' : 'var(--surface)',
      color: active ? '#fff' : 'var(--text-2)',
      fontSize: 12, fontWeight: 500, cursor: 'pointer',
      transition: 'all var(--transition)',
    }}>
      {color && <span style={{ width: 6, height: 6, borderRadius: '1px', background: active ? 'rgba(255,255,255,.7)' : color, display: 'inline-block', flexShrink: 0 }} />}
      {label}
      {count != null && (
        <span style={{
          fontSize: 11, fontWeight: 700,
          background: active ? 'rgba(255,255,255,.2)' : 'var(--surface-2)',
          color: active ? '#fff' : 'var(--text-3)',
          borderRadius: '2px', padding: '0 5px', lineHeight: '18px',
        }}>{count}</span>
      )}
    </button>
  )
}

/* Result row */
function ResultRow({ result, onClick }) {
  const pass = result.hardened
  /* Normalise state — strip any trailing leftover text if regex was imperfect */
  const stateLabel = pass ? 'HARDENED' : 'NOT HARDENED'

  return (
    <div
      className="animate-in"
      onClick={() => onClick && onClick(result)}
      style={{
        display: 'grid',
        gridTemplateColumns: '28px 1fr 120px',
        alignItems: 'center', gap: 10,
        padding: '10px 16px',
        borderBottom: '1px solid var(--border)',
        cursor: 'pointer',
        transition: 'background var(--transition)',
      }}
      onMouseEnter={e => e.currentTarget.style.background = 'var(--surface-2)'}
      onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
    >
      {/* Icon */}
      <div style={{
        width: 24, height: 24,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: pass ? 'var(--green-bg)' : 'var(--red-bg)',
        color: pass ? 'var(--green)' : 'var(--red)',
        borderRadius: 'var(--radius-sm)',
        flexShrink: 0,
      }}>
        {pass ? <CheckCircle2 size={13} /> : <XCircle size={13} />}
      </div>

      {/* Name */}
      <span style={{ fontSize: 13, fontWeight: 400, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        {result.name}
      </span>

      {/* Badge — always clean label, no raw junk */}
      <span style={{
        display: 'inline-block',
        fontSize: 11, fontWeight: 600,
        padding: '2px 7px',
        borderRadius: 'var(--radius-sm)',
        textAlign: 'center',
        background: pass ? 'var(--green-bg)' : 'var(--red-bg)',
        color: pass ? 'var(--green)' : 'var(--red)',
        border: `1px solid ${pass ? 'var(--green-ring)' : 'var(--red-ring)'}`,
        letterSpacing: '.2px',
      }}>
        {stateLabel}
      </span>
    </div>
  )
}

function ProgressStrip({ label, pct }) {
  return (
    <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--border)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 8, fontSize: 12.5, color: 'var(--text-2)', fontWeight: 500 }}>
        <LoaderCircle size={13} color="var(--accent)" className="spin" />
        {label}
      </div>
      <div style={{ height: 4, background: 'var(--surface-2)', borderRadius: 1, overflow: 'hidden' }}>
        <div style={{ height: '100%', background: 'var(--accent)', width: `${pct}%`, transition: 'width 400ms ease' }} />
      </div>
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

/* ══ MAIN ══════════════════════════════════════════════════════════════════ */
export default function AuditTab({ modules }) {
  const [folder,   setFolder]   = useState('')
  const [severity, setSeverity] = useState('basic')
  const [running,  setRunning]  = useState(false)
  const [checks,   setChecks]   = useState([])
  const [summary,  setSummary]  = useState(null)
  const [filter,   setFilter]   = useState('all')
  const [modal,    setModal]    = useState(null)
  const [progress, setProgress] = useState(0)

  async function runAudit() {
    setRunning(true); setChecks([]); setSummary(null); setProgress(0); setFilter('all')
    const all = []
    for await (const obj of streamNDJSON('/api/audit', { folder, severity })) {
      if (obj.type === 'summary') {
        setSummary(obj)
      } else if (obj.type === 'check') {
        all.push(obj)
        setChecks([...all])
        setProgress(p => Math.min(p + 1.5, 93))
      }
    }
    setProgress(100); setRunning(false)
  }

  const visible = checks.filter(c =>
    filter === 'hardened'     ? c.hardened  :
    filter === 'not_hardened' ? !c.hardened : true
  )
  const hardCount  = summary?.hardened     ?? checks.filter(c => c.hardened).length
  const notCount   = summary?.not_hardened ?? checks.filter(c => !c.hardened).length
  const totalCount = summary?.executed     ?? checks.length

  return (
    <>
      {/* Controls bar */}
      <div style={{
        display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between',
        flexWrap: 'wrap', gap: 16, marginBottom: 20,
      }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 700, letterSpacing: '-.2px' }}>System Audit</h2>
          <p style={{ fontSize: 12.5, color: 'var(--text-2)', marginTop: 3 }}>
            Runs <code style={{ fontFamily: 'monospace', background: 'var(--surface-2)', border: '1px solid var(--border)', padding: '1px 5px', borderRadius: 'var(--radius-sm)', fontSize: 12 }}>beetle audit [module] [severity]</code>
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, flexWrap: 'wrap' }}>
          <FormalSelect label="Module" value={folder} onChange={setFolder}>
            <option value="">All modules</option>
            {modules.audit.map(f => (
              <option key={f} value={f}>{f.replace(/_/g, ' ')}</option>
            ))}
          </FormalSelect>
          <FormalSelect label="Severity" value={severity} onChange={setSeverity}>
            {modules.severities.map(s => <option key={s} value={s}>{s}</option>)}
          </FormalSelect>
          <PrimaryBtn onClick={runAudit} disabled={running} loading={running}
            icon={ScanSearch} label={running ? 'Running…' : 'Run Audit'} />
        </div>
      </div>

      {/* Empty */}
      {!running && checks.length === 0 && (
        <div style={{
          textAlign: 'center', padding: '72px 24px', color: 'var(--text-3)',
          border: '1px dashed var(--border)', borderRadius: 'var(--radius-lg)',
          background: 'var(--surface)',
        }}>
          <ScanSearch size={36} style={{ margin: '0 auto 12px', display: 'block', opacity: .4 }} />
          <p style={{ fontSize: 13 }}>Configure options above, then click <strong style={{ color: 'var(--text-2)' }}>Run Audit</strong>.</p>
        </div>
      )}

      {/* Layout */}
      {(running || checks.length > 0) && (
        <div style={{ display: 'grid', gridTemplateColumns: '252px 1fr', gap: 16, alignItems: 'start' }}>

          {/* Donut */}
          <Card style={{ position: 'sticky', top: 74 }}>
            <CardHead><CardTitle icon={PieChart}>Compliance</CardTitle></CardHead>
            <div style={{ padding: '18px 16px 14px' }}>
              <DonutChart hardened={hardCount} total={totalCount} />

              {/* Legend */}
              <div style={{ borderTop: '1px solid var(--border)', marginTop: 16, paddingTop: 14 }}>
                {[
                  { label: 'Hardened',     count: hardCount,  color: 'var(--green-stroke)', f: 'hardened'     },
                  { label: 'Not Hardened', count: notCount,   color: 'var(--red-stroke)',   f: 'not_hardened' },
                  { label: 'Total',        count: totalCount, color: 'var(--text-3)',        f: 'all'          },
                ].map(it => (
                  <div
                    key={it.f}
                    onClick={() => setFilter(it.f)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 8,
                      cursor: 'pointer', padding: '5px 6px',
                      borderRadius: 'var(--radius-sm)',
                      background: filter === it.f ? 'var(--surface-2)' : 'transparent',
                      border: `1px solid ${filter === it.f ? 'var(--border)' : 'transparent'}`,
                      marginBottom: 3,
                      transition: 'all var(--transition)',
                    }}
                  >
                    <span style={{ width: 8, height: 8, borderRadius: '1px', background: it.color, flexShrink: 0 }} />
                    <span style={{ flex: 1, fontSize: 12.5, color: 'var(--text-2)' }}>{it.label}</span>
                    <span style={{ fontSize: 13, fontWeight: 700 }}>{it.count}</span>
                  </div>
                ))}
              </div>
            </div>
          </Card>

          {/* Results */}
          <Card>
            <CardHead>
              <CardTitle icon={ListChecks}>Check Results</CardTitle>
              <div style={{ display: 'flex', gap: 4 }}>
                <FilterTab key="all" label="All" active={filter==='all'} count={totalCount} onClick={() => setFilter('all')} />
                <FilterTab label="Hardened"    color="var(--green-stroke)" active={filter==='hardened'}     count={hardCount} onClick={() => setFilter('hardened')}     />
                <FilterTab label="Not Hardened" color="var(--red-stroke)"   active={filter==='not_hardened'} count={notCount}  onClick={() => setFilter('not_hardened')} />
              </div>
            </CardHead>

            {running && <ProgressStrip label={`Running audit… ${checks.length} checks complete`} pct={progress} />}

            <div style={{ maxHeight: 500, overflowY: 'auto' }}>
              {visible.length === 0 && !running && (
                <div style={{ padding: '36px 24px', textAlign: 'center', color: 'var(--text-3)', fontSize: 13 }}>
                  No results for this filter.
                </div>
              )}
              {visible.map((r, i) => <ResultRow key={i} result={r} onClick={() => setModal(r)} />)}
            </div>

            {summary && (
              <SummaryFooter items={[
                { icon: CheckCircle2,  label: 'Hardened',     val: summary.hardened,     color: 'var(--green)' },
                { icon: XCircle,       label: 'Not Hardened', val: summary.not_hardened, color: 'var(--red)'   },
                { icon: AlertTriangle, label: 'Skipped',      val: summary.skipped,      color: 'var(--text-3)'},
                { icon: List,          label: 'Total',        val: summary.executed,     color: 'var(--text-3)'},
              ]} />
            )}
          </Card>
        </div>
      )}

      {modal && <ResultModal result={modal} mode="audit" onClose={() => setModal(null)} />}
    </>
  )
}
