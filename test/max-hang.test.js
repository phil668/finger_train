import test from 'node:test';
import assert from 'node:assert/strict';
import { MaxHangTest, formatStopwatch } from '../src/max-hang.js';

test('max hang measures elapsed wall time and can restart', () => {
  let now = 1000;
  const testTimer = new MaxHangTest(() => now);
  testTimer.start();
  now += 12540;
  assert.equal(testTimer.elapsedMs, 12540);
  assert.equal(testTimer.stop(), 12540);
  now += 5000;
  assert.equal(testTimer.elapsedMs, 12540);
  testTimer.start();
  now += 3000;
  assert.equal(testTimer.stop(), 3000);
  testTimer.reset();
  assert.equal(testTimer.elapsedMs, 0);
  assert.equal(testTimer.phase, 'ready');
});

test('stopwatch display uses minutes after sixty seconds', () => {
  assert.equal(formatStopwatch(59900), '59.9');
  assert.equal(formatStopwatch(60000), '1:00.0');
  assert.equal(formatStopwatch(125400), '2:05.4');
});
