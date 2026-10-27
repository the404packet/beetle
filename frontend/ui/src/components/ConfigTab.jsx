import { useState, useEffect } from 'react'
import { FileJson, Save, RefreshCw, ChevronDown, ChevronRight, Plus, Trash2, Code, List } from 'lucide-react'

// A recursive component to edit JSON visually
function JsonNode({ label, value, onChange, onDelete, isRoot = false }) {
  const [expanded, setExpanded] = useState(true)
  const [newKey, setNewKey] = useState('')
  const [showAdd, setShowAdd] = useState(false)

  if (typeof value === 'object' && value !== null) {
    const isArray = Array.isArray(value)
    return (
      <div style={{ 
        marginLeft: isRoot ? 0 : 16, 
        borderLeft: isRoot ? 'none' : '1px solid var(--border)', 
        paddingLeft: isRoot ? 0 : 12, 
        marginTop: isRoot ? 0 : 8,
        marginBottom: isRoot ? 24 : 0
      }}>
        {!isRoot && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
            <button onClick={() => setExpanded(!expanded)} style={{ background: 'none', border: 'none', color: 'var(--text-3)', cursor: 'pointer', padding: 0 }}>
              {expanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
            </button>
            <span style={{ fontWeight: 600, color: 'var(--text-2)', fontSize: 13 }}>{label}</span>
            {onDelete && (
              <button onClick={onDelete} style={{ background: 'none', border: 'none', color: 'var(--text-3)', cursor: 'pointer', marginLeft: 'auto', padding: '0 4px' }}>
                <Trash2 size={13} />
              </button>
            )}
          </div>
        )}
        
        {expanded && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            {Object.entries(value).map(([k, v]) => (
              <JsonNode 
                key={k} 
                label={isArray ? `[${k}]` : k} 
                value={v} 
                onChange={(newVal) => {
                  const copy = isArray ? [...value] : { ...value }
                  copy[k] = newVal
                  onChange(copy)
                }}
                onDelete={isArray ? () => {
                  const copy = [...value]
                  copy.splice(Number(k), 1)
                  onChange(copy)
                } : () => {
                  const copy = { ...value }
                  delete copy[k]
                  onChange(copy)
                }}
              />
            ))}
            
            {isArray ? (
              <button 
                onClick={() => onChange([...value, ''])}
                style={{ 
                  alignSelf: 'flex-start', background: 'transparent', border: '1px dashed var(--border)', 
                  color: 'var(--text-3)', padding: '4px 8px', borderRadius: 4, cursor: 'pointer', 
                  fontSize: 11, display: 'flex', alignItems: 'center', gap: 4, marginTop: 4, marginLeft: 16 
                }}
              >
                <Plus size={12} /> Add Item
              </button>
            ) : (
              <div style={{ marginLeft: 16, marginTop: 4 }}>
                {showAdd ? (
                  <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
                    <input 
                      type="text" 
                      placeholder="New key name" 
                      value={newKey}
                      onChange={e => setNewKey(e.target.value)}
                      style={{ background: 'var(--bg-2)', color: 'var(--text-1)', border: '1px solid var(--border)', borderRadius: 4, padding: '4px 8px', fontSize: 12, outline: 'none' }}
                      onKeyDown={e => {
                        if (e.key === 'Enter' && newKey) {
                          const copy = { ...value, [newKey]: '' }
                          onChange(copy)
                          setNewKey('')
                          setShowAdd(false)
                        }
                      }}
                    />
                    <button 
                      onClick={() => {
                        if (newKey) {
                          const copy = { ...value, [newKey]: '' }
                          onChange(copy)
                          setNewKey('')
                          setShowAdd(false)
                        }
                      }}
                      style={{ background: 'var(--accent)', color: '#fff', border: 'none', borderRadius: 4, padding: '4px 8px', cursor: 'pointer', fontSize: 12 }}
                    >
                      Add
                    </button>
                    <button onClick={() => setShowAdd(false)} style={{ background: 'transparent', color: 'var(--text-3)', border: 'none', cursor: 'pointer', fontSize: 12 }}>
                      Cancel
                    </button>
                  </div>
                ) : (
                  <button 
                    onClick={() => setShowAdd(true)}
                    style={{ 
                      background: 'transparent', border: '1px dashed var(--border)', 
                      color: 'var(--text-3)', padding: '4px 8px', borderRadius: 4, cursor: 'pointer', 
                      fontSize: 11, display: 'flex', alignItems: 'center', gap: 4 
                    }}
                  >
                    <Plus size={12} /> Add Field
                  </button>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    )
  }

  // Primitive value
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4, marginLeft: 16 }}>
      <span style={{ color: 'var(--text-2)', fontSize: 13, width: 180, flexShrink: 0, textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
        {label}
      </span>
      {typeof value === 'boolean' ? (
        <select 
          value={value.toString()} 
          onChange={e => onChange(e.target.value === 'true')}
          style={{ background: 'var(--bg-2)', color: 'var(--text-1)', border: '1px solid var(--border)', borderRadius: 4, padding: '6px 8px', fontSize: 13, outline: 'none' }}
        >
          <option value="true">true</option>
          <option value="false">false</option>
        </select>
      ) : typeof value === 'number' ? (
        <input 
          type="number" 
          value={value} 
          onChange={e => onChange(Number(e.target.value))}
          style={{ background: 'var(--bg-2)', color: 'var(--text-1)', border: '1px solid var(--border)', borderRadius: 4, padding: '6px 8px', fontSize: 13, outline: 'none', width: '100%', maxWidth: 300 }}
        />
      ) : (
        <input 
          type="text" 
          value={value} 
          onChange={e => onChange(e.target.value)}
          style={{ background: 'var(--bg-2)', color: 'var(--text-1)', border: '1px solid var(--border)', borderRadius: 4, padding: '6px 8px', fontSize: 13, outline: 'none', width: '100%', maxWidth: 300 }}
        />
      )}
      {onDelete && (
        <button onClick={onDelete} style={{ background: 'none', border: 'none', color: 'var(--text-4)', cursor: 'pointer', padding: 4 }} title="Remove field">
          <Trash2 size={13} />
        </button>
      )}
    </div>
  )
}

export default function ConfigTab() {
  const [files, setFiles] = useState([])
  const [selectedFile, setSelectedFile] = useState('')
  const [content, setContent] = useState('')
  
  // View mode: 'form' | 'code'
  const [viewMode, setViewMode] = useState('form')
  
  // Parsed JSON for form view
  const [parsedData, setParsedData] = useState(null)
  const [parseError, setParseError] = useState(false)

  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState({ text: '', type: '' })

  useEffect(() => {
    fetchFiles()
  }, [])

  // Sync content string -> parsedData
  useEffect(() => {
    if (viewMode === 'form') {
      try {
        const parsed = JSON.parse(content)
        setParsedData(parsed)
        setParseError(false)
      } catch (e) {
        setParseError(true)
      }
    }
  }, [content, viewMode])

  const fetchFiles = async () => {
    try {
      const res = await fetch('/api/config/files')
      const data = await res.json()
      setFiles(data.files || [])
      if (data.files && data.files.length > 0 && !selectedFile) {
        handleSelectFile(data.files[0])
      }
    } catch (err) {
      console.error(err)
    }
  }

  const handleSelectFile = async (filename) => {
    setSelectedFile(filename)
    setLoading(true)
    setMessage({ text: '', type: '' })
    try {
      const res = await fetch(`/api/config/${filename}`)
      const data = await res.json()
      setContent(data.content || '')
    } catch (err) {
      console.error(err)
      setMessage({ text: 'Failed to load file', type: 'error' })
    } finally {
      setLoading(false)
    }
  }

  const handleSave = async () => {
    if (!selectedFile) return
    setSaving(true)
    setMessage({ text: '', type: '' })
    
    let contentToSave = content
    if (viewMode === 'form' && !parseError && parsedData) {
      contentToSave = JSON.stringify(parsedData, null, 2)
      setContent(contentToSave) // sync back to text
    }

    try {
      const res = await fetch(`/api/config/${selectedFile}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: contentToSave })
      })
      const data = await res.json()
      if (data.ok) {
        setMessage({ text: 'Saved successfully!', type: 'success' })
      } else {
        setMessage({ text: `Save failed: ${data.error}`, type: 'error' })
      }
    } catch (err) {
      setMessage({ text: 'Network error', type: 'error' })
    } finally {
      setSaving(false)
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20, height: '100%' }}>
      
      {/* Header section */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: 20, fontWeight: 700, margin: 0, color: 'var(--text-1)' }}>JSON Configuration</h2>
          <p style={{ fontSize: 13, color: 'var(--text-3)', margin: '4px 0 0 0' }}>
            Edit JSON rules and configuration files for Beetle modules.
          </p>
        </div>
        
        <div style={{ display: 'flex', gap: 10 }}>
          <select 
            value={selectedFile} 
            onChange={(e) => handleSelectFile(e.target.value)}
            style={{
              background: 'var(--bg-2)',
              color: 'var(--text-1)',
              border: '1px solid var(--border)',
              borderRadius: 'var(--radius-md)',
              padding: '8px 12px',
              fontSize: 13,
              outline: 'none',
              cursor: 'pointer'
            }}
          >
            {files.map(f => <option key={f} value={f}>{f}</option>)}
          </select>
          
          <button 
            onClick={fetchFiles}
            className="action-button"
            title="Refresh list"
            style={{ padding: '8px 12px' }}
          >
            <RefreshCw size={15} />
          </button>
        </div>
      </div>

      {/* Editor section */}
      <div className="card" style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: 0, overflow: 'hidden' }}>
        <div style={{ 
          padding: '12px 16px', 
          borderBottom: '1px solid var(--border)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          background: 'var(--bg-2)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, color: 'var(--text-2)' }}>
              <FileJson size={16} />
              <span style={{ fontWeight: 600 }}>{selectedFile || 'No file selected'}</span>
            </div>
            
            <div style={{ display: 'flex', background: 'var(--bg-1)', borderRadius: 6, padding: 2 }}>
              <button 
                onClick={() => setViewMode('form')}
                style={{ 
                  display: 'flex', alignItems: 'center', gap: 6, padding: '4px 10px', 
                  border: 'none', borderRadius: 4, cursor: 'pointer', fontSize: 12, fontWeight: 500,
                  background: viewMode === 'form' ? 'var(--accent)' : 'transparent',
                  color: viewMode === 'form' ? '#fff' : 'var(--text-3)'
                }}
              >
                <List size={14} /> Form
              </button>
              <button 
                onClick={() => setViewMode('code')}
                style={{ 
                  display: 'flex', alignItems: 'center', gap: 6, padding: '4px 10px', 
                  border: 'none', borderRadius: 4, cursor: 'pointer', fontSize: 12, fontWeight: 500,
                  background: viewMode === 'code' ? 'var(--accent)' : 'transparent',
                  color: viewMode === 'code' ? '#fff' : 'var(--text-3)'
                }}
              >
                <Code size={14} /> Code
              </button>
            </div>
          </div>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            {message.text && (
              <span style={{ 
                fontSize: 12, 
                color: message.type === 'error' ? '#ff5a5a' : '#4ade80' 
              }}>
                {message.text}
              </span>
            )}
            
            <button 
              onClick={handleSave} 
              disabled={loading || saving || !selectedFile || (viewMode === 'form' && parseError)}
              className="action-button primary"
              style={{ padding: '6px 14px', fontSize: 13, display: 'flex', alignItems: 'center', gap: 6 }}
            >
              <Save size={14} />
              {saving ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </div>
        
        <div style={{ flex: 1, position: 'relative', overflowY: 'auto' }}>
          {loading ? (
            <div style={{ 
              position: 'absolute', inset: 0, 
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: 'var(--text-3)', fontSize: 14 
            }}>
              Loading...
            </div>
          ) : viewMode === 'form' ? (
            parseError ? (
              <div style={{ padding: 32, textAlign: 'center', color: '#ff5a5a' }}>
                <FileJson size={32} style={{ opacity: 0.5, marginBottom: 12 }} />
                <p>Invalid JSON format. Please fix syntax errors in Code view before using Form view.</p>
              </div>
            ) : parsedData ? (
              <div style={{ padding: '24px 32px' }}>
                <JsonNode 
                  label="root" 
                  value={parsedData} 
                  isRoot={true}
                  onChange={(newData) => {
                    setParsedData(newData)
                  }} 
                />
              </div>
            ) : null
          ) : (
            <textarea 
              value={content}
              onChange={(e) => setContent(e.target.value)}
              spellCheck="false"
              style={{
                width: '100%',
                height: '100%',
                minHeight: '500px',
                resize: 'none',
                background: 'transparent',
                color: 'var(--text-1)',
                border: 'none',
                padding: '24px',
                fontSize: 13,
                fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
                lineHeight: 1.6,
                outline: 'none',
              }}
            />
          )}
        </div>
      </div>
      
    </div>
  )
}
