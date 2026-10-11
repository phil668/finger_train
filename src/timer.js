const HANG_SECONDS = 7;
const REST_SECONDS = 3;

export class RepeaterTimer {
  constructor(onUpdate = () => {}, onCue = () => {}) {
    this.onUpdate = onUpdate;
    this.onCue = onCue;
    this.repetitionsPerSet = 5;
    this.preparationSeconds = 3;
    this.reset();
    this.interval = setInterval(() => this.tick(), 100);
  }

  get phaseLabel() {
    return {
      ready: 'READY', preparing: 'GET ON', hanging: 'HANG',
      resting: 'REST', setComplete: 'SET DONE', finished: 'FINISHED'
    }[this.phase];
  }

  get statusLine() {
    return {
      ready: 'Set your grip and start when ready',
      preparing: 'Find the edge and settle your fingers',
      hanging: 'Keep your shoulders engaged',
      resting: 'Release and relax your fingers',
      setComplete: 'Choose another set or finish the session',
      finished: 'Session complete'
    }[this.phase];
  }

  get primaryButtonTitle() {
    if (this.phase === 'setComplete') return `START SET ${this.completedSets + 1}`;
    if (this.phase === 'finished') return 'NEW SESSION';
    if (this.running) return 'PAUSE';
    if (this.phase === 'ready') return 'START SET 1';
    return 'RESUME';
  }

  get activeSetNumber() {
    return this.phase === 'setComplete' || this.phase === 'finished'
      ? Math.max(1, this.completedSets)
      : this.completedSets + 1;
  }

  get currentRepetitionDisplay() {
    if (this.phase === 'ready') return 0;
    if (this.phase === 'setComplete' || this.phase === 'finished') return this.repetitionsPerSet;
    return this.currentRepetition;
  }

  get completedRepetitionMarkers() {
    if (this.phase === 'ready' || this.phase === 'preparing') return 0;
    if (this.phase === 'hanging') return this.currentRepetition - 1;
    if (this.phase === 'resting') return this.currentRepetition;
    return this.repetitionsPerSet;
  }

  get progress() {
    if (this.phase === 'setComplete' || this.phase === 'finished') return 1;
    if (this.phase === 'ready') return 0;
    return Math.max(0, Math.min(1, 1 - this.remaining / this.phaseDuration));
  }

  get estimatedSetDuration() {
    const seconds = this.preparationSeconds + this.repetitionsPerSet * HANG_SECONDS +
      (this.repetitionsPerSet - 1) * REST_SECONDS;
    return seconds >= 60 ? `${Math.floor(seconds / 60)}m ${seconds % 60}s` : `${seconds}s`;
  }

  configure({ repetitionsPerSet = this.repetitionsPerSet, preparationSeconds = this.preparationSeconds }) {
    if (this.phase !== 'ready') return;
    this.repetitionsPerSet = Math.max(1, Math.min(12, Math.round(repetitionsPerSet)));
    this.preparationSeconds = Math.max(2, Math.min(10, Math.round(preparationSeconds)));
    this.onUpdate();
  }

  toggle() {
    if (this.phase === 'finished') this.reset();
    if (this.phase === 'ready' || this.phase === 'setComplete') {
      this.startSet();
    } else if (this.running) {
      this.pause();
    } else {
      this.running = true;
      this.endAt = Date.now() + this.remaining * 1000;
      this.onUpdate();
    }
  }

  startSet() {
    this.currentRepetition = 1;
    this.phase = 'preparing';
    this.phaseDuration = this.preparationSeconds;
    this.remaining = this.phaseDuration;
    this.endAt = Date.now() + this.remaining * 1000;
    this.running = true;
    this.lastCount = null;
    this.onCue('Get on');
    this.onUpdate();
  }

  pause() {
    if (!this.running) return;
    this.remaining = Math.max(0, (this.endAt - Date.now()) / 1000);
    this.running = false;
    this.onUpdate();
  }

  finishSession() {
    if (this.phase !== 'setComplete') return;
    this.phase = 'finished';
    this.running = false;
    this.onCue('Session complete');
    this.onUpdate();
  }

  reset() {
    this.phase = 'ready';
    this.phaseDuration = HANG_SECONDS;
    this.remaining = HANG_SECONDS;
    this.currentRepetition = 0;
    this.completedSets = 0;
    this.running = false;
    this.endAt = 0;
    this.lastCount = null;
    this.onUpdate();
  }

  advancePhase() {
    if (this.phase === 'preparing') {
      this.phase = 'hanging';
      this.phaseDuration = HANG_SECONDS;
      return 'Hang';
    }
    if (this.phase === 'hanging') {
      if (this.currentRepetition >= this.repetitionsPerSet) {
        this.completedSets++;
        this.phase = 'setComplete';
        this.running = false;
        this.remaining = 0;
        return `Set ${this.completedSets} complete`;
      }
      this.phase = 'resting';
      this.phaseDuration = REST_SECONDS;
      return 'Rest';
    }
    if (this.phase === 'resting') {
      this.currentRepetition++;
      this.phase = 'hanging';
      this.phaseDuration = HANG_SECONDS;
      return 'Hang';
    }
    return '';
  }

  tick() {
    if (!this.running) return;
    const now = Date.now();
    let cue = '';
    while (this.running && now >= this.endAt) {
      const previousEnd = this.endAt;
      cue = this.advancePhase();
      this.lastCount = null;
      if (this.running) this.endAt = previousEnd + this.phaseDuration * 1000;
    }
    if (cue) this.onCue(cue);
    if (this.running) {
      this.remaining = Math.max(0, (this.endAt - now) / 1000);
      const count = Math.ceil(this.remaining);
      if (this.phase === 'hanging' && count > 0 && count <= 3 && count !== this.lastCount) {
        this.onCue(String(count));
      }
      this.lastCount = count;
    }
    this.onUpdate();
  }
}
