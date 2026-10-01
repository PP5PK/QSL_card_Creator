import { displayFreq, formatQsoDate, formatQsoTime, type Qso } from "@/lib/qso";

function Line({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value || <span className="qsl-rule" aria-label="blank" />}</dd>
    </div>
  );
}

export function QslCard({ qso }: { qso: Qso }) {
  return (
    <article id="qsl-sheet" className="qsl" aria-label="QSL card of PP5PK">
      <img
        className="qsl-bg"
        src="/card/bg.jpg?v=5"
        alt=""
        crossOrigin="anonymous"
        draggable={false}
      />
      <div className="qsl-scrim" />
      <div className="qsl-frame" />
      <header className="qsl-id">
        <h1 className="qsl-call">PP5PK</h1>
        <p className="qsl-name">Daniel Kondlatsch</p>
        <p className="qsl-qth">Mafra · Santa Catarina · Brazil</p>
        <p className="qsl-grid">GG53cu • IARU R-2 • ITU Z-15 • CQ Z-11</p>
        <p className="qsl-site">pp5pk.net</p>
      </header>
      <aside className="qsl-qso" aria-label="QSO data">
        <p className="qso-kicker">QSO</p>
        <dl className="qso-rows">
          <Line label="Call" value={qso.call} />
          <Line label="Date UTC" value={formatQsoDate(qso.date)} />
          <Line label="Time UTC" value={formatQsoTime(qso.time)} />
          <Line label="Freq / Band" value={displayFreq(qso.freq)} />
          <Line label="Mode" value={qso.mode} />
        </dl>
      </aside>
    </article>
  );
}
