interface Props {
  onNow: () => void
  onPast: () => void
  onBack: () => void
}

export function Classify({ onNow, onPast, onBack }: Props) {
  return (
    <div className="screen">
      <div className="topbar">
        <button className="back-link" onClick={onBack}>
          ← 返回
        </button>
      </div>

      <div style={{ textAlign: 'center', marginTop: 40, marginBottom: 48 }}>
        <h1 className="title">这份感受，来自哪里？</h1>
        <p className="subtitle" style={{ marginTop: 12 }}>
          有没有强烈地想起某件事？
        </p>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        <button className="fork-card glass" onClick={onNow}>
          <h3>它属于此刻</h3>
          <p>只是现在的一阵波动。轻轻记下来就好，不需要多说什么。</p>
        </button>

        <button
          className="fork-card glass"
          onClick={onPast}
          style={{
            borderColor: 'rgba(139, 124, 246, 0.4)',
            boxShadow: '0 0 40px rgba(139, 124, 246, 0.12)',
          }}
        >
          <h3 style={{ color: '#c9befc' }}>它来自过去的某一天</h3>
          <p>某段时光在敲门。跟我走，我们一起回去看看——那天发生了什么，你有多难过，或者有多开心。</p>
        </button>
      </div>
    </div>
  )
}
