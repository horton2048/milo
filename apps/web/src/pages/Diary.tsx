import { useEffect, useRef, useState } from 'react'
import { ensureAcp } from '../lib/acp'
import { buildDiaryPrompt, fallbackDiary } from '../lib/guide'
import type { Draft } from '../types'

interface Props {
  draft: Draft
  onSave: (diary: string | undefined, diaryEnabled: boolean) => void
  onBack: () => void
}

export function Diary({ draft, onSave, onBack }: Props) {
  const [enabled, setEnabled] = useState(true)
  const [diary, setDiary] = useState('')
  const [generating, setGenerating] = useState(true)
  const [editing, setEditing] = useState(false)
  const generatedRef = useRef(false)

  useEffect(() => {
    if (!enabled || generatedRef.current) return
    generatedRef.current = true
    let alive = true

    const gen = async () => {
      setGenerating(true)
      const client = await ensureAcp()
      if (!alive) return
      if (client) {
        try {
          let acc = ''
          const full = await client.prompt(buildDiaryPrompt(draft), (d) => {
            acc += d
            if (alive) setDiary(acc)
          })
          if (!alive) return
          setDiary(full.trim())
        } catch {
          if (alive) setDiary(fallbackDiary(draft))
        }
      } else {
        setDiary(fallbackDiary(draft))
      }
      if (alive) setGenerating(false)
    }

    void gen()
    return () => {
      alive = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled])

  return (
    <div className="screen screen-scroll">
      <div className="topbar">
        <button className="back-link" onClick={onBack}>
          ← 返回对话
        </button>
        <span className="eyebrow">{draft.timeMark}</span>
        <span style={{ width: 68 }} />
      </div>

      <div style={{ textAlign: 'center', marginBottom: 20 }}>
        <h1 className="title">显影这段回忆</h1>
        <p className="subtitle" style={{ marginTop: 8 }}>
          我们把刚才的对话，写成了一篇属于你的日记。
        </p>
      </div>

      <div className="switch-row glass" style={{ marginBottom: 18 }}>
        <div>
          <div style={{ fontSize: 14.5 }}>沉淀为日记</div>
          <div className="hint">以你的视角书写；关闭则只保留对话记录</div>
        </div>
        <button
          className={`switch ${enabled ? 'on' : ''}`}
          onClick={() => setEnabled((v) => !v)}
          aria-label="沉淀为日记"
        >
          <i />
        </button>
      </div>

      {enabled && (
        <div className="diary-paper fade-in" style={{ marginBottom: 20 }}>
          {generating && !diary ? (
            <span className="hint">
              回忆正在显影
              <span className="typing-dots" style={{ marginLeft: 8 }}>
                <i />
                <i />
                <i />
              </span>
            </span>
          ) : editing ? (
            <textarea className="diary-edit" value={diary} onChange={(e) => setDiary(e.target.value)} />
          ) : (
            diary
          )}
        </div>
      )}

      {enabled && !generating && (
        <button className="btn btn-ghost" style={{ marginBottom: 12 }} onClick={() => setEditing((v) => !v)}>
          {editing ? '完成编辑' : '修改一下措辞'}
        </button>
      )}

      <button
        className="btn btn-primary"
        disabled={enabled && generating}
        onClick={() => onSave(enabled ? diary : undefined, enabled)}
      >
        收进回忆
      </button>
    </div>
  )
}
