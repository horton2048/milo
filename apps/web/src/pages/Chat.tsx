import { useEffect, useRef, useState } from 'react'
import { ensureAcp, type AcpClient } from '../lib/acp'
import { buildOpeningPrompt, FallbackGuide } from '../lib/guide'
import { useSpeech } from '../lib/speech'
import type { ChatMessage, Draft } from '../types'

interface Props {
  draft: Draft
  onFinish: (transcript: ChatMessage[], usedAcp: boolean) => void
  onBack: () => void
}

type Mode = 'connecting' | 'acp' | 'fallback'

export function Chat({ draft, onFinish, onBack }: Props) {
  const [mode, setMode] = useState<Mode>('connecting')
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [input, setInput] = useState('')
  const [busy, setBusy] = useState(true)
  const [streaming, setStreaming] = useState('')

  const clientRef = useRef<AcpClient | null>(null)
  const guideRef = useRef<FallbackGuide | null>(null)
  const listRef = useRef<HTMLDivElement>(null)
  const startedRef = useRef(false)

  const speech = useSpeech((text) => setInput((prev) => (prev ? prev + ' ' : '') + text))

  const push = (m: ChatMessage) => setMessages((prev) => [...prev, m])

  // 自动滚动到底部
  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight, behavior: 'smooth' })
  }, [messages, streaming])

  // 初始化：连接 ACP 或启用兜底引导
  useEffect(() => {
    if (startedRef.current) return
    startedRef.current = true
    let alive = true

    const boot = async () => {
      const client = await ensureAcp()
      if (!alive) return
      if (client) {
        clientRef.current = client
        setMode('acp')
        try {
          let acc = ''
          setStreaming(' ')
          const full = await client.prompt(buildOpeningPrompt(draft), (d) => {
            acc += d
            if (alive) setStreaming(acc)
          })
          if (!alive) return
          setStreaming('')
          push({ role: 'ai', text: full.trim(), ts: Date.now() })
        } catch {
          if (!alive) return
          setStreaming('')
          startFallback()
        }
      } else {
        startFallback()
      }
      if (alive) setBusy(false)
    }

    const startFallback = () => {
      const g = new FallbackGuide(draft.timeMark ?? '过去的某一天')
      guideRef.current = g
      setMode('fallback')
      push({ role: 'ai', text: g.opening(), ts: Date.now() })
    }

    void boot()
    return () => {
      alive = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const send = async () => {
    const text = input.trim()
    if (!text || busy) return
    setInput('')
    push({ role: 'user', text, ts: Date.now() })
    setBusy(true)

    if (mode === 'acp' && clientRef.current) {
      try {
        let acc = ''
        setStreaming(' ')
        const full = await clientRef.current.prompt(text, (d) => {
          acc += d
          setStreaming(acc)
        })
        setStreaming('')
        push({ role: 'ai', text: full.trim(), ts: Date.now() })
      } catch {
        setStreaming('')
        // ACP 中途失败 → 切换兜底
        const g = new FallbackGuide(draft.timeMark ?? '过去的某一天')
        guideRef.current = g
        setMode('fallback')
        push({ role: 'ai', text: g.next(), ts: Date.now() })
      }
    } else if (guideRef.current) {
      // 模拟一点思考时间，让节奏更柔和
      await new Promise((r) => setTimeout(r, 900 + Math.random() * 600))
      push({ role: 'ai', text: guideRef.current.next(), ts: Date.now() })
    }
    setBusy(false)
  }

  const userSpoke = messages.some((m) => m.role === 'user')

  return (
    <div className="screen">
      <div className="topbar">
        <button className="back-link" onClick={onBack}>
          ← 离开
        </button>
        <span className="eyebrow">{draft.timeMark}</span>
        <span className="hint" style={{ width: 48, textAlign: 'right' }}>
          {mode === 'acp' ? 'AI' : mode === 'fallback' ? '引导' : '…'}
        </span>
      </div>

      <div className="chat-list" ref={listRef}>
        {mode === 'connecting' && (
          <div className="bubble ai">
            <span className="hint">正在点亮回忆的灯…</span>
            <span className="typing-dots" style={{ marginLeft: 8 }}>
              <i />
              <i />
              <i />
            </span>
          </div>
        )}
        {messages.map((m, i) => (
          <div key={i} className={`bubble ${m.role}`}>
            {m.text}
          </div>
        ))}
        {streaming && (
          <div className="bubble ai">
            {streaming.trim() || (
              <span className="typing-dots">
                <i />
                <i />
                <i />
              </span>
            )}
          </div>
        )}
        {busy && !streaming && mode !== 'connecting' && (
          <div className="bubble ai">
            <span className="typing-dots">
              <i />
              <i />
              <i />
            </span>
          </div>
        )}
      </div>

      {userSpoke && !busy && (
        <button
          className="btn"
          style={{ marginBottom: 12, borderColor: 'rgba(139,124,246,0.5)', color: '#c9befc' }}
          onClick={() => onFinish(messages, mode === 'acp')}
        >
          ✦ 沉淀这段回忆
        </button>
      )}

      <div className="chat-input-bar glass">
        <textarea
          className="chat-input"
          rows={1}
          placeholder={speech.listening ? speech.interim || '正在聆听…' : '说说那时的事…'}
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
              e.preventDefault()
              void send()
            }
          }}
        />
        {speech.supported && (
          <button
            className={`icon-btn ${speech.listening ? 'rec' : ''}`}
            title={speech.listening ? '停止' : '语音输入'}
            onClick={() => (speech.listening ? speech.stop() : speech.start())}
          >
            {speech.listening ? '◼' : '🎙'}
          </button>
        )}
        <button className="icon-btn" onClick={() => void send()} disabled={busy || !input.trim()} title="发送">
          ↑
        </button>
      </div>
    </div>
  )
}
