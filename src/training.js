const STORAGE_KEY = 'hangbeat-training-v1';
const MAX_RECORDS = 1000;

export function localDayKey(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function calendarDays(year, month) {
  const offset = (new Date(year, month, 1).getDay() + 6) % 7;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cells = Math.ceil((offset + daysInMonth) / 7) * 7;
  return Array.from({ length: cells }, (_, index) => {
    const day = index - offset + 1;
    return day >= 1 && day <= daysInMonth ? day : null;
  });
}

export function monthSummary(records, year, month) {
  const prefix = `${year}-${String(month + 1).padStart(2, '0')}-`;
  const monthRecords = records.filter(record => record.day.startsWith(prefix));
  return {
    days: new Set(monthRecords.map(record => record.day)).size,
    sets: monthRecords.filter(record => record.type === 'repeater').length,
    bestHangMs: Math.max(0, ...monthRecords.filter(record => record.type === 'maxHang').map(record => record.durationMs))
  };
}

export function formatHang(durationMs) {
  const seconds = Math.max(0, durationMs) / 1000;
  if (seconds < 60) return `${seconds.toFixed(1)}s`;
  return `${Math.floor(seconds / 60)}m ${(seconds % 60).toFixed(1)}s`;
}

function validRecord(record) {
  if (!record || typeof record !== 'object' || !/^\d{4}-\d{2}-\d{2}$/.test(record.day) || typeof record.at !== 'string') return false;
  if (record.type === 'repeater') return Number.isInteger(record.repetitions) && record.repetitions >= 1 && record.repetitions <= 12;
  if (record.type === 'maxHang') return Number.isFinite(record.durationMs) && record.durationMs > 0;
  return false;
}

export class TrainingLog {
  constructor(storage = globalThis.localStorage) {
    this.storage = storage;
    try {
      const parsed = JSON.parse(storage.getItem(STORAGE_KEY));
      this.records = Array.isArray(parsed) ? parsed.filter(validRecord).slice(-MAX_RECORDS) : [];
    } catch {
      this.records = [];
    }
  }

  addRepeater(repetitions, when = new Date()) {
    return this.add({ type: 'repeater', repetitions, day: localDayKey(when), at: when.toISOString() });
  }

  addMaxHang(durationMs, when = new Date()) {
    return this.add({ type: 'maxHang', durationMs: Math.round(durationMs), day: localDayKey(when), at: when.toISOString() });
  }

  add(record) {
    if (!validRecord(record)) return null;
    this.records = [...this.records, record].slice(-MAX_RECORDS);
    try { this.storage.setItem(STORAGE_KEY, JSON.stringify(this.records)); }
    catch { /* Results still remain available until the page closes. */ }
    return record;
  }

  get bestHangMs() {
    return Math.max(0, ...this.records.filter(record => record.type === 'maxHang').map(record => record.durationMs));
  }

  get lastHangMs() {
    return [...this.records].reverse().find(record => record.type === 'maxHang')?.durationMs ?? 0;
  }
}
