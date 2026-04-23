import { useEffect, useRef } from 'react'

const CIRC = 2 * Math.PI * 75   // ≈ 471.24

/**
 * DonutChart
 * Props:
 *   hardened: number
 *   total:    number
 */
export default function DonutChart({ hardened = 0, total = 0 }) {
  const greenRef = useRef(null)
  const redRef   = useRef(null)
  const pctRef   = useRef(null)

  useEffect(() => {
    if (!greenRef.current) return
    const pct        = total > 0 ? hardened / total : 0
    const greenDash  = pct * CIRC
    const redDash    = (1 - pct) * CIRC

    greenRef.current.style.strokeDasharray  = `${greenDash} ${CIRC}`
    greenRef.current.style.strokeDashoffset = '0'

    redRef.current.style.strokeDasharray    = `${redDash} ${CIRC}`
    redRef.current.style.strokeDashoffset   = `-${greenDash}`

    if (pctRef.current) {
      pctRef.current.textContent = total > 0 ? `${Math.round(pct * 100)}%` : '—'
    }
  }, [hardened, total])

  return (
    <svg viewBox="0 0 200 200" style={{ width: 160, height: 160, transform: 'rotate(-90deg)', overflow: 'visible', display: 'block', margin: '0 auto' }}>
      {/* Background ring */}
      <circle cx="100" cy="100" r="75" fill="none" stroke="var(--surface-2)" strokeWidth="22" />

      {/* Green (hardened) */}
      <circle
        ref={greenRef}
        cx="100" cy="100" r="75"
        fill="none"
        stroke="var(--green-stroke)"
        strokeWidth="22"
        strokeDasharray="0 471"
        strokeDashoffset="0"
        style={{ transition: 'stroke-dasharray 700ms cubic-bezier(.4,0,.2,1)' }}
      />

      {/* Red (not hardened) */}
      <circle
        ref={redRef}
        cx="100" cy="100" r="75"
        fill="none"
        stroke="var(--red-stroke)"
        strokeWidth="22"
        strokeDasharray="0 471"
        strokeDashoffset="0"
        style={{ transition: 'stroke-dasharray 700ms cubic-bezier(.4,0,.2,1), stroke-dashoffset 700ms cubic-bezier(.4,0,.2,1)' }}
      />

      {/* Center text — counter-rotate so it reads upright */}
      <text
        ref={pctRef}
        x="100" y="95"
        textAnchor="middle"
        style={{
          font: '700 28px Inter, sans-serif',
          fill: 'var(--text-1)',
          transform: 'rotate(90deg)',
          transformOrigin: '100px 100px',
          letterSpacing: '-1px',
        }}
      >
        {total > 0 ? `${Math.round((hardened / total) * 100)}%` : '—'}
      </text>
      <text
        x="100" y="115"
        textAnchor="middle"
        style={{
          font: '500 11px Inter, sans-serif',
          fill: 'var(--text-3)',
          transform: 'rotate(90deg)',
          transformOrigin: '100px 100px',
        }}
      >
        Hardened
      </text>
    </svg>
  )
}
