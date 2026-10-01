import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { domToPng } from "modern-screenshot";
import { QslCard } from "@/components/qsl-card";
import {
  EMPTY_QSO,
  cleanCall,
  fileName,
  loadQso,
  normalizeDate,
  normalizeTime,
  nowUtc,
  qsoFromSearch,
  saveQso,
  toQuery,
  type Qso,
} from "@/lib/qso";

export const Route = createFileRoute("/")({ component: Home });

const MODES = ["APRS", "PACKET", "FM", "SSB", "CW", "FT8"] as const;

function Home() {
  const [qso, setQso] = useState<Qso>(EMPTY_QSO);
  const [ready, setReady] = useState(false);
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const fromUrl = qsoFromSearch(window.location.search);
    setQso(fromUrl ?? loadQso() ?? EMPTY_QSO);
    setReady(true);
  }, []);

  useEffect(() => {
    if (ready) saveQso(qso);
  }, [qso, ready]);

  function patch(partial: Partial<Qso>) {
    setQso((current) => ({ ...current, ...partial }));
    setNote("");
  }

  async function onDownload() {
    const node = document.getElementById("qsl-sheet");
    if (!node) return;
    setBusy(true);
    setNote("");
    try {
      await document.fonts.ready;
      const scale = Math.min(3, Math.max(2, 1700 / node.clientWidth));
      const url = await domToPng(node, { scale, backgroundColor: "#14241c" });
      const link = document.createElement("a");
      link.href = url;
      link.download = fileName(qso);
      link.click();
    } catch {
      setNote("Could not make the PNG. Use Print and save as PDF.");
    } finally {
      setBusy(false);
    }
  }

  async function onCopy() {
    const query = toQuery(qso);
    try {
      await navigator.clipboard.writeText(query);
      setNote("Parameters copied.");
    } catch {
      setNote("Select the line below and copy it.");
    }
  }

  const query = toQuery(qso);

  return (
    <main className="desk">
      <header className="studio-chrome mast">
        <div>
          <p className="mast-kicker">QSL card · front only · 140 × 90 mm</p>
          <p className="mast-title">PP5PK · Mafra, Santa Catarina</p>
        </div>
        <p className="mast-note">
          The QSO panel sits in the footer, on the right, translucent over the
          bridge, the honey and the river.
        </p>
      </header>

      <div className="desk-grid">
        <div className="qsl-stage">
          <QslCard qso={qso} />
        </div>

        <form
          className="studio-chrome log"
          onSubmit={(event) => event.preventDefault()}
        >
          <div>
            <p className="log-kicker">QSO log</p>
            <p className="log-lead">Type it in, or let APRS open the page already filled.</p>
          </div>

          <label className="field">
            <span>Call</span>
            <input
              value={qso.call}
              autoCapitalize="characters"
              autoComplete="off"
              spellCheck={false}
              maxLength={16}
              placeholder="PY2AAA"
              onChange={(event) => patch({ call: cleanCall(event.target.value) })}
            />
          </label>

          <div className="field-pair">
            <label className="field">
              <span>Date UTC</span>
              <input
                type="date"
                value={qso.date}
                onChange={(event) => patch({ date: normalizeDate(event.target.value) })}
              />
            </label>
            <label className="field">
              <span>Time UTC</span>
              <input
                type="time"
                value={qso.time}
                onChange={(event) => patch({ time: normalizeTime(event.target.value) })}
              />
            </label>
          </div>

          <label className="field">
            <span>Frequency / band</span>
            <input
              value={qso.freq}
              autoComplete="off"
              spellCheck={false}
              maxLength={24}
              placeholder="144.390"
              onChange={(event) => patch({ freq: event.target.value.slice(0, 24) })}
            />
          </label>

          <div className="field">
            <span>Mode</span>
            <div className="mode-row">
              {MODES.map((mode) => (
                <button
                  key={mode}
                  type="button"
                  className={qso.mode === mode ? "chip chip-on" : "chip"}
                  onClick={() => patch({ mode })}
                >
                  {mode}
                </button>
              ))}
            </div>
            <input
              value={qso.mode}
              autoComplete="off"
              spellCheck={false}
              maxLength={16}
              onChange={(event) =>
                patch({ mode: event.target.value.toUpperCase().slice(0, 16) })
              }
            />
          </div>

          <div className="log-actions">
            <button
              type="button"
              className="btn"
              onClick={() => patch(nowUtc())}
            >
              Now UTC
            </button>
            <button
              type="button"
              className="btn"
              onClick={() => patch({ call: "", date: "", time: "" })}
            >
              Clear
            </button>
            <button type="button" className="btn btn-primary" onClick={() => window.print()}>
              Print
            </button>
            <button
              type="button"
              className="btn btn-primary"
              disabled={busy}
              onClick={() => void onDownload()}
            >
              {busy ? "Working…" : "Download PNG"}
            </button>
          </div>

          <div className="auto">
            <div className="auto-head">
              <p>For APRS to fill this in</p>
              <button type="button" className="text-btn" onClick={() => void onCopy()}>
                Copy
              </button>
            </div>
            <code>{query || "call, date, time, freq, mode"}</code>
            <p className="auto-hint">
              Add this line to the page address. Example: call=PY2AAA &
              date=2026-09-30 & time=0757 & freq=144.390 & mode=APRS
            </p>
          </div>

          {note ? (
            <p className="log-note" role="status">
              {note}
            </p>
          ) : null}
        </form>
      </div>
    </main>
  );
}
