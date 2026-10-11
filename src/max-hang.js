export function formatStopwatch(durationMs) {
  const seconds = Math.max(0, durationMs) / 1000;
  if (seconds < 60) return seconds.toFixed(1);
  return `${Math.floor(seconds / 60)}:${(seconds % 60).toFixed(1).padStart(4, '0')}`;
}

export class MaxHangTest {
  constructor(now = () => Date.now()) {
    this.now = now;
    this.reset();
  }

  get running() { return this.phase === 'running'; }

  get elapsedMs() {
    return this.running ? Math.max(0, this.now() - this.startedAt) : this.resultMs;
  }

  start() {
    if (this.running) return;
    this.startedAt = this.now();
    this.resultMs = 0;
    this.phase = 'running';
  }

  stop() {
    if (!this.running) return null;
    this.resultMs = this.elapsedMs;
    this.phase = 'result';
    return this.resultMs;
  }

  reset() {
    this.phase = 'ready';
    this.startedAt = 0;
    this.resultMs = 0;
  }
}
