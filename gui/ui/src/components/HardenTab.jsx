import { useState } from 'react'
import { Shield, Terminal, CheckCircle2, XCircle, List, AlertTriangle } from 'lucide-react'
import {
  Card, CardHead, CardTitle, Select, PrimaryBtn,
  ResultRow, ProgressStrip, SummaryFooter, EmptyState, PageHeader,
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

  const btnLabel = running
    ? 'Running…'
    : folder
      ? `Harden: ${folder.replace(/_/g, ' ')}`
      : 'Harden All'

  return (
    <>
      {/* Controls — identical structure to AuditTab */}
      <PageHeader title="System Hardening" description="beetle harden [module] [severity]">
        <Select label="Module" value={folder} onChange={setFolder}>
          <option value="">All modules</option>
          {modules.harden.map(f => (
            <option key={f} value={f}>{f.replace(/_/g, ' ')}</option>
          ))}
        </Select>
        <Select label="Severity" value={severity} onChange={setSeverity}>
          {modules.severities.map(s => <option key={s} value={s}>{s}</option>)}
        </Select>
        <PrimaryBtn
          onClick={runHarden}
          disabled={running}
          loading={running}
          icon={Shield}
          label={btnLabel}
        />
      </PageHeader>

      {/* Empty state — identical structure to AuditTab */}
      {!running && results.length === 0 && (
        <EmptyState
          icon={Shield}
          title="No hardening results yet"
          subtitle="Configure options above, then click"
          accentWord={folder ? `Harden: ${folder.replace(/_/g, ' ')}` : 'Harden All'}
        />
      )}

      {/* Results — single full-width card, same as AuditTab results card */}
      {(running || results.length > 0) && (
        <Card>
          <CardHead>
            <CardTitle icon={Terminal}>Harden Results</CardTitle>
            <span style={{ fontSize: 12, color: 'var(--text-3)' }}>
              {running ? `Running… ${results.length} scripts done` : `${total} scripts executed`}
            </span>
          </CardHead>

          {running && (
            <ProgressStrip
              label={`Applying hardening… ${results.length} scripts done`}
              pct={progress}
            />
          )}

          <div style={{ maxHeight: 500, overflowY: 'auto' }}>
            {results.length === 0 && running && (
              <div style={{ padding: '40px 24px', textAlign: 'center', color: 'var(--text-3)', fontSize: 13 }}>
                Starting…
              </div>
            )}
            {results.map((r, i) => (
              <ResultRow
                key={i}
                pass={r.success}
                name={r.name}
                badgeText={r.success ? 'SUCCESS' : 'FAILED'}
              />
            ))}
          </div>

          {summary && (
            <SummaryFooter items={[
              { icon: CheckCircle2,  label: 'Succeeded', val: succeeded,          color: 'var(--green-stroke)' },
              { icon: XCircle,       label: 'Failed',    val: failed,             color: 'var(--red-stroke)'   },
              { icon: AlertTriangle, label: 'Skipped',   val: summary.skipped ?? 0, color: 'var(--text-3)'    },
              { icon: List,          label: 'Total',     val: total,              color: 'var(--text-3)'       },
            ]} />
          )}
        </Card>
      )}
    </>
  )
}
