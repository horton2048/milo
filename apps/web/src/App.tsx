import { useState } from 'react'
import { BlackHoleGalaxy } from './components/BlackHoleGalaxy'
import { Starfield } from './components/Starfield'
import { isBlackHoleGalaxyDemo } from './components/blackHoleGalaxyModel'
import { Home } from './pages/Home'
import { Classify } from './pages/Classify'
import { NowNote } from './pages/NowNote'
import { PastTime } from './pages/PastTime'
import { Chat } from './pages/Chat'
import { Diary } from './pages/Diary'
import { Card } from './pages/Card'
import { Timeline } from './pages/Timeline'
import { Detail } from './pages/Detail'
import { addEntry, getEntry, uid, useEntries } from './store'
import { resetAcp } from './lib/acp'
import type { ChatMessage, Draft, Entry, Screen } from './types'

const EMPTY_DRAFT: Draft = { mood: { valence: 0, labels: [] }, transcript: [], diaryEnabled: true }
const BLACK_HOLE_DEMO = isBlackHoleGalaxyDemo(window.location.search)

export default function App() {
  const [screen, setScreen] = useState<Screen>({ name: 'home' })
  const [draft, setDraft] = useState<Draft>(EMPTY_DRAFT)
  const entries = useEntries()

  const go = (s: Screen) => setScreen(s)

  const saveNow = (note: string) => {
    const entry: Entry = {
      id: uid(),
      createdAt: Date.now(),
      kind: 'now',
      mood: draft.mood,
      note: note || undefined,
      diaryEnabled: false,
    }
    addEntry(entry)
    setDraft(EMPTY_DRAFT)
    go({ name: 'card', entryId: entry.id })
  }

  const finishChat = (transcript: ChatMessage[]) => {
    setDraft((d) => ({ ...d, transcript }))
    go({ name: 'diary' })
  }

  const savePast = (diary: string | undefined, diaryEnabled: boolean) => {
    const entry: Entry = {
      id: uid(),
      createdAt: Date.now(),
      kind: 'past',
      mood: draft.mood,
      timeMark: draft.timeMark,
      transcript: draft.transcript,
      diary,
      diaryEnabled,
    }
    addEntry(entry)
    setDraft(EMPTY_DRAFT)
    resetAcp() // 结束本次 ACP 会话，下次回忆重新开始
    go({ name: 'card', entryId: entry.id })
  }

  const abandon = () => {
    setDraft(EMPTY_DRAFT)
    resetAcp()
    go({ name: 'home' })
  }

  return (
    <div className={`stage ${BLACK_HOLE_DEMO ? 'stage--black-hole-demo' : ''}`}>
      {BLACK_HOLE_DEMO ? (
        <BlackHoleGalaxy />
      ) : (
        <>
          <div className="aurora" />
          <Starfield />
        </>
      )}

      {screen.name === 'home' && (
        <Home
          echoVoid={BLACK_HOLE_DEMO}
          entryCount={entries.length}
          onTimeline={() => go({ name: 'timeline' })}
          onNext={(mood) => {
            setDraft({ ...EMPTY_DRAFT, mood })
            go({ name: 'classify' })
          }}
        />
      )}

      {screen.name === 'classify' && (
        <Classify
          onBack={() => go({ name: 'home' })}
          onNow={() => go({ name: 'now-note' })}
          onPast={() => go({ name: 'past-time' })}
        />
      )}

      {screen.name === 'now-note' && (
        <NowNote mood={draft.mood} onBack={() => go({ name: 'classify' })} onSave={saveNow} />
      )}

      {screen.name === 'past-time' && (
        <PastTime
          onBack={() => go({ name: 'classify' })}
          onNext={(timeMark) => {
            setDraft((d) => ({ ...d, timeMark }))
            go({ name: 'chat' })
          }}
        />
      )}

      {screen.name === 'chat' && <Chat draft={draft} onBack={abandon} onFinish={finishChat} />}

      {screen.name === 'diary' && <Diary draft={draft} onBack={() => go({ name: 'chat' })} onSave={savePast} />}

      {screen.name === 'card' && (
        <CardOrHome
          entryId={screen.entryId}
          onDone={() => go({ name: 'timeline' })}
          onHome={() => go({ name: 'home' })}
        />
      )}

      {screen.name === 'timeline' && (
        <Timeline onBack={() => go({ name: 'home' })} onOpen={(id) => go({ name: 'detail', entryId: id })} />
      )}

      {screen.name === 'detail' && (
        <Detail
          entryId={screen.entryId}
          onBack={() => go({ name: 'timeline' })}
          onCard={(id) => go({ name: 'card', entryId: id })}
        />
      )}
    </div>
  )
}

function CardOrHome({
  entryId,
  onDone,
  onHome,
}: {
  entryId: string
  onDone: () => void
  onHome: () => void
}) {
  const entry = getEntry(entryId)
  if (!entry) {
    onDone()
    return null
  }
  return <Card entry={entry} onDone={onDone} onHome={onHome} />
}
