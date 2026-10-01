import { useState } from 'react'
import { ScanSearch, PieChart, ListChecks, CheckCircle2, XCircle, List, AlertTriangle } from 'lucide-react'
import DonutChart from './DonutChart'
import ResultModal from './ResultModal'
import {
  Card, CardHead, CardTitle, Select, PrimaryBtn,
  FilterTab, ResultRow, ProgressStrip, SummaryFooter, EmptyState, PageHeader,
} from './shared'

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
      <PageHeader title="System Audit" description="beetle audit [module] [severity]">
        <Select label="Module" value={folder} onChange={setFolder}>
          <option value="">All modules</option>
          {modules.audit.map(f => <option key={f} value={f}>{f.replace(/_/g, ' ')}</option>)}
        </Select>
        <Select label="Severity" value={severity} onChange={setSeverity}>
          {modules.severities.map(s => <option key={s} value={s}>{s}</option>)}
        </Select>
        <PrimaryBtn onClick={runAudit} disabled={running} loading={running}
          icon={ScanSearch} label={running ? 'Running…' : 'Run Audit'} />
      </PageHeader>

      {/* Empty state */}
      {!running && checks.length === 0 && (
        <EmptyState
          icon={ScanSearch}
          title="No audit results yet"
          subtitle="Configure options above, then click"
          accentWord="Run Audit"
        />
      )}

      {/* Results layout */}
      {(running || checks.length > 0) && (
        <div style={{ display: 'grid', gridTemplateColumns: '256px 1fr', gap: 16, alignItems: 'start' }}>

          {/* Compliance donut */}
          <Card style={{ position: 'sticky', top: 0 }}>
            <CardHead><CardTitle icon={PieChart}>Compliance</CardTitle></CardHead>
            <div style={{ padding: '20px 18px 16px' }}>
              <DonutChart hardened={hardCount} total={totalCount} />

              {/* Legend / filter */}
              <div style={{ borderTop: '1px solid var(--border)', marginTop: 18, paddingTop: 14, display: 'flex', flexDirection: 'column', gap: 2 }}>
                {[
                  { label: 'Hardened',     count: hardCount,  color: 'var(--green-stroke)', f: 'hardened'     },
                  { label: 'Not Hardened', count: notCount,   color: 'var(--red-stroke)',   f: 'not_hardened' },
                  { label: 'Total',        count: totalCount, color: 'var(--text-3)',        f: 'all'          },
                ].map(it => (
                  <div
                    key={it.f}
                    onClick={() => setFilter(it.f)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 9,
                      cursor: 'pointer', padding: '6px 8px',
                      borderRadius: 'var(--radius-sm)',
                      background: filter === it.f ? 'var(--surface-2)' : 'transparent',
                      border: `1px solid ${filter === it.f ? 'var(--border-solid)' : 'transparent'}`,
                      transition: 'all var(--transition)',
                    }}
                  >
                    <span style={{ width: 8, height: 8, borderRadius: '2px', background: it.color, flexShrink: 0 }} />
                    <span style={{ flex: 1, fontSize: 12.5, color: 'var(--text-2)' }}>{it.label}</span>
                    <span style={{ fontSize: 13.5, fontWeight: 700, color: 'var(--text-1)' }}>{it.count}</span>
                  </div>
                ))}
              </div>
            </div>
          </Card>

          {/* Results list */}
          <Card>
            <CardHead>
              <CardTitle icon={ListChecks}>Check Results</CardTitle>
              <div style={{ display: 'flex', gap: 4 }}>
                <FilterTab label="All"          active={filter==='all'}          count={totalCount} onClick={() => setFilter('all')}          />
                <FilterTab label="Hardened"     active={filter==='hardened'}     count={hardCount}  onClick={() => setFilter('hardened')}     color="var(--green-stroke)" />
                <FilterTab label="Not Hardened" active={filter==='not_hardened'} count={notCount}   onClick={() => setFilter('not_hardened')} color="var(--red-stroke)"   />
              </div>
            </CardHead>

            {running && <ProgressStrip label={`Running audit… ${checks.length} checks complete`} pct={progress} />}

            <div style={{ maxHeight: 500, overflowY: 'auto' }}>
              {visible.length === 0 && !running && (
                <div style={{ padding: '40px 24px', textAlign: 'center', color: 'var(--text-3)', fontSize: 13 }}>
                  No results for this filter.
                </div>
              )}
              {visible.map((r, i) => (
                <ResultRow
                  key={i}
                  pass={r.hardened}
                  name={r.name}
                  badgeText={r.hardened ? 'HARDENED' : 'NOT HARDENED'}
                  onClick={() => setModal(r)}
                />
              ))}
            </div>

            {summary && (
              <SummaryFooter items={[
                { icon: CheckCircle2,  label: 'Hardened',     val: summary.hardened,     color: 'var(--green-stroke)' },
                { icon: XCircle,       label: 'Not Hardened', val: summary.not_hardened, color: 'var(--red-stroke)'   },
                { icon: AlertTriangle, label: 'Skipped',      val: summary.skipped,      color: 'var(--text-3)'       },
                { icon: List,          label: 'Total',        val: summary.executed,     color: 'var(--text-3)'       },
              ]} />
            )}
          </Card>
        </div>
      )}

      {modal && <ResultModal result={modal} mode="audit" onClose={() => setModal(null)} />}
    </>
  )
}
