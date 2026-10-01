export type Qso = {
  call: string;
  date: string;
  time: string;
  freq: string;
  mode: string;
};

const STORAGE_KEY = "pp5pk-qsl-qso";

const MONTHS = [
  "JAN",
  "FEB",
  "MAR",
  "APR",
  "MAY",
  "JUN",
  "JUL",
  "AUG",
  "SEP",
  "OCT",
  "NOV",
  "DEC",
] as const;

export const EMPTY_QSO: Qso = {
  call: "",
  date: "",
  time: "",
  freq: "144.390",
  mode: "APRS",
};

export function cleanCall(raw: string): string {
  return raw.toUpperCase().replace(/[^A-Z0-9/]/g, "").slice(0, 16);
}

export function normalizeDate(raw: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(raw.trim());
  if (!match) return "";
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) return "";
  return `${match[1]}-${match[2]}-${match[3]}`;
}

export function normalizeTime(raw: string): string {
  const trimmed = raw.trim();
  const clock = /^(\d{1,2}):(\d{2})/.exec(trimmed);
  if (clock) {
    const hh = Number(clock[1]);
    const mm = Number(clock[2]);
    if (hh > 23 || mm > 59) return "";
    return `${String(hh).padStart(2, "0")}:${clock[2]}`;
  }
  const digits = trimmed.replace(/\D/g, "");
  if (digits.length !== 4) return "";
  const hh = Number(digits.slice(0, 2));
  const mm = Number(digits.slice(2));
  if (hh > 23 || mm > 59) return "";
  return `${digits.slice(0, 2)}:${digits.slice(2)}`;
}

export function qsoFromSearch(search: string): Qso | null {
  const params = new URLSearchParams(search);
  const keys = ["call", "date", "time", "freq", "mode"] as const;
  if (!keys.some((key) => params.has(key))) return null;
  return {
    call: cleanCall(params.get("call") ?? ""),
    date: normalizeDate(params.get("date") ?? ""),
    time: normalizeTime(params.get("time") ?? ""),
    freq: (params.get("freq") ?? EMPTY_QSO.freq).trim().slice(0, 24),
    mode: (params.get("mode") ?? EMPTY_QSO.mode).trim().toUpperCase().slice(0, 16) || "APRS",
  };
}

export function toQuery(qso: Qso): string {
  const params = new URLSearchParams();
  if (qso.call) params.set("call", qso.call);
  if (qso.date) params.set("date", qso.date);
  if (qso.time) params.set("time", qso.time);
  if (qso.freq) params.set("freq", qso.freq);
  if (qso.mode) params.set("mode", qso.mode);
  return params.toString();
}

export function formatQsoDate(iso: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  if (!match) return "";
  const month = MONTHS[Number(match[2]) - 1];
  if (!month) return "";
  return `${match[3]} ${month} ${match[1]}`;
}

export function formatQsoTime(time: string): string {
  return time ? `${time}Z` : "";
}

export function displayFreq(freq: string): string {
  const trimmed = freq.trim();
  if (!trimmed) return "";
  if (/^[\d]+[.,][\d]+$/.test(trimmed) || /^\d{3}$/.test(trimmed)) {
    return `${trimmed.replace(",", ".")} MHz`;
  }
  return trimmed;
}

export function nowUtc(): Pick<Qso, "date" | "time"> {
  const iso = new Date().toISOString();
  return { date: iso.slice(0, 10), time: iso.slice(11, 16) };
}

export function loadQso(): Qso | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<Qso>;
    return {
      call: cleanCall(parsed.call ?? ""),
      date: normalizeDate(parsed.date ?? ""),
      time: normalizeTime(parsed.time ?? ""),
      freq: (parsed.freq ?? EMPTY_QSO.freq).trim().slice(0, 24),
      mode: (parsed.mode ?? EMPTY_QSO.mode).trim().toUpperCase().slice(0, 16) || "APRS",
    };
  } catch {
    return null;
  }
}

export function saveQso(qso: Qso) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(qso));
  } catch {
    /* the card still works without persistence */
  }
}

export function fileName(qso: Qso): string {
  const call = qso.call || "CONTATO";
  const stamp = qso.date ? qso.date.replaceAll("-", "") : "QSL";
  return `PP5PK_${call}_${stamp}.png`;
}
