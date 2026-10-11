import test from 'node:test';
import assert from 'node:assert/strict';
import { RepeaterTimer } from '../src/timer.js';

test('7/3 transitions prepare once, then alternate hang and rest', () => {
  const originalNow = Date.now;
  let now = 100000;
  Date.now = () => now;
  const timer = new RepeaterTimer();
  try {
    assert.equal(timer.repetitionsPerSet, 5);
    timer.toggle();
    assert.equal(timer.phase, 'preparing');
    now += 3000;
    timer.tick();
    assert.equal(timer.phase, 'hanging');
    now += 7000;
    timer.tick();
    assert.equal(timer.phase, 'resting');
    now += 3000;
    timer.tick();
    assert.equal(timer.phase, 'hanging');
    assert.equal(timer.currentRepetition, 2);
  } finally {
    clearInterval(timer.interval);
    Date.now = originalNow;
  }
});

test('pause preserves time and each completed set can start another', () => {
  const originalNow = Date.now;
  let now = 200000;
  Date.now = () => now;
  const timer = new RepeaterTimer();
  try {
    timer.configure({ repetitionsPerSet: 1, preparationSeconds: 2 });
    timer.toggle();
    now += 1000;
    timer.pause();
    assert.equal(timer.running, false);
    assert.equal(timer.remaining, 1);
    now += 10000;
    timer.toggle();
    now += 1000;
    timer.tick();
    assert.equal(timer.phase, 'hanging');
    now += 7000;
    timer.tick();
    assert.equal(timer.phase, 'setComplete');
    assert.equal(timer.completedSets, 1);
    timer.toggle();
    assert.equal(timer.phase, 'preparing');
    assert.equal(timer.activeSetNumber, 2);
  } finally {
    clearInterval(timer.interval);
    Date.now = originalNow;
  }
});
