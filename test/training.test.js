import test from 'node:test';
import assert from 'node:assert/strict';
import { TrainingLog, calendarDays, formatHang, localDayKey, monthSummary } from '../src/training.js';

test('calendar starts on Monday and includes leap day', () => {
  const days = calendarDays(2024, 1);
  assert.deepEqual(days.slice(0, 5), [null, null, null, 1, 2]);
  assert.equal(days.filter(Boolean).length, 29);
  assert.equal(days.length, 35);
});

test('completed sets and max hangs persist and summarize by local day', () => {
  const values = new Map();
  const storage = {
    getItem: key => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value)
  };
  const log = new TrainingLog(storage);
  const first = new Date(2026, 9, 11, 12);
  const second = new Date(2026, 9, 12, 12);
  log.addRepeater(5, first);
  log.addMaxHang(27340, first);
  log.addMaxHang(31500, second);
  assert.equal(localDayKey(first), '2026-10-11');
  assert.deepEqual(monthSummary(log.records, 2026, 9), { days: 2, sets: 1, bestHangMs: 31500 });
  assert.equal(log.bestHangMs, 31500);
  assert.equal(log.lastHangMs, 31500);
  assert.equal(new TrainingLog(storage).records.length, 3);
  assert.equal(formatHang(64000), '1m 4.0s');
});
