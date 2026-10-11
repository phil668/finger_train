import { RepeaterTimer } from './src/timer.js';

const SETTINGS_KEY = 'hangbeat-timer-v1';
const ring = document.getElementById('progress-ring');
const resetButton = document.getElementById('reset-button');
const resetIcon = resetButton.innerHTML;
const voiceButton = document.getElementById('voice-button');
const installButton = document.getElementById('install-button');
const toastElement = document.getElementById('toast');
let deferredInstall = null;
let wakeLock = null;
let toastTimeout = null;
let markerKey = '';
let timer;

function readSettings() {
  try { return JSON.parse(localStorage.getItem(SETTINGS_KEY)) ?? {}; }
  catch { return {}; }
}

const settings = readSettings();
let voiceEnabled = settings.voiceEnabled !== false;

function saveSettings() {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify({
      repetitionsPerSet: timer.repetitionsPerSet,
      preparationSeconds: timer.preparationSeconds,
      voiceEnabled
    }));
  } catch { /* The timer continues to work if storage is unavailable. */ }
}

function showToast(message) {
  toastElement.textContent = message;
  toastElement.classList.add('show');
  clearTimeout(toastTimeout);
  toastTimeout = setTimeout(() => toastElement.classList.remove('show'), 3000);
}

function speak(message) {
  if (!voiceEnabled || !('speechSynthesis' in window)) return;
  window.speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(message);
  utterance.lang = 'en-US';
  utterance.rate = 1.05;
  window.speechSynthesis.speak(utterance);
  if ('vibrate' in navigator && !/^\d+$/.test(message)) navigator.vibrate(40);
}

async function requestWakeLock() {
  try {
    if ('wakeLock' in navigator && !wakeLock) {
      wakeLock = await navigator.wakeLock.request('screen');
      if (!timer.running) releaseWakeLock();
    }
  } catch { /* Not all browsers support keeping the display awake. */ }
}

function releaseWakeLock() {
  wakeLock?.release().catch(() => {});
  wakeLock = null;
}

function updateView() {
  if (!timer) return;
  const timerElement = document.getElementById('timer');
  timerElement.className = `timer ${timer.phase}`;
  timerElement.setAttribute('aria-label', `${timer.phaseLabel}, ${Math.ceil(timer.remaining)} seconds remaining, ${timer.statusLine}`);
  ring.style.strokeDasharray = '100';
  ring.style.strokeDashoffset = `${100 * (1 - timer.progress)}`;
  document.getElementById('phase').textContent = timer.phaseLabel;
  document.getElementById('seconds').textContent = ['setComplete', 'finished'].includes(timer.phase)
    ? '✓' : Math.ceil(timer.remaining);
  document.getElementById('set-label').textContent = `SET ${timer.activeSetNumber} · HANGS`;
  document.getElementById('repetition-count').textContent = `${timer.currentRepetitionDisplay} / ${timer.repetitionsPerSet}`;
  document.getElementById('primary-title').textContent = timer.primaryButtonTitle;
  document.getElementById('primary-icon').textContent = timer.running ? 'Ⅱ' : '▶';
  document.getElementById('status').textContent = timer.statusLine;
  document.getElementById('duration').textContent = `PER SET · ${timer.estimatedSetDuration}`;
  document.getElementById('hang-value').textContent = timer.repetitionsPerSet;
  document.getElementById('setup-value').textContent = `${timer.preparationSeconds}s`;
  document.getElementById('completed-sets').textContent = `${timer.completedSets} set${timer.completedSets === 1 ? '' : 's'} completed`;

  const isReady = timer.phase === 'ready';
  document.getElementById('hang-minus').disabled = !isReady || timer.repetitionsPerSet <= 1;
  document.getElementById('hang-plus').disabled = !isReady || timer.repetitionsPerSet >= 12;
  document.getElementById('setup-minus').disabled = !isReady || timer.preparationSeconds <= 2;
  document.getElementById('setup-plus').disabled = !isReady || timer.preparationSeconds >= 10;
  const isSetComplete = timer.phase === 'setComplete';
  document.getElementById('controls').classList.toggle('has-finish', isSetComplete);
  resetButton.innerHTML = isSetComplete ? 'FINISH' : resetIcon;
  resetButton.setAttribute('aria-label', isSetComplete ? 'Finish session' : 'Reset session');
  resetButton.disabled = isReady;

  const nextMarkerKey = `${timer.repetitionsPerSet}:${timer.completedRepetitionMarkers}`;
  if (nextMarkerKey !== markerKey) {
    document.getElementById('markers').innerHTML = Array.from({ length: timer.repetitionsPerSet }, (_, index) =>
      `<span class="marker ${index < timer.completedRepetitionMarkers ? 'done' : ''}"></span>`
    ).join('');
    markerKey = nextMarkerKey;
  }
  if (!timer.running && wakeLock) releaseWakeLock();
}

timer = new RepeaterTimer(updateView, speak);
if (Number.isInteger(settings.repetitionsPerSet) && Number.isInteger(settings.preparationSeconds)) {
  timer.configure({
    repetitionsPerSet: settings.repetitionsPerSet,
    preparationSeconds: settings.preparationSeconds
  });
}
voiceButton.setAttribute('aria-pressed', String(voiceEnabled));
voiceButton.setAttribute('aria-label', voiceEnabled ? 'Turn voice off' : 'Turn voice on');
updateView();

document.getElementById('primary-button').addEventListener('click', () => {
  if (timer.running) window.speechSynthesis?.cancel();
  timer.toggle();
  if (timer.running) requestWakeLock();
});

resetButton.addEventListener('click', () => {
  if (timer.phase === 'setComplete') timer.finishSession();
  else {
    window.speechSynthesis?.cancel();
    timer.reset();
  }
  releaseWakeLock();
});

voiceButton.addEventListener('click', () => {
  voiceEnabled = !voiceEnabled;
  if (!voiceEnabled) window.speechSynthesis?.cancel();
  voiceButton.setAttribute('aria-pressed', String(voiceEnabled));
  voiceButton.setAttribute('aria-label', voiceEnabled ? 'Turn voice off' : 'Turn voice on');
  saveSettings();
});

for (const [id, field, delta] of [
  ['hang-minus', 'repetitionsPerSet', -1], ['hang-plus', 'repetitionsPerSet', 1],
  ['setup-minus', 'preparationSeconds', -1], ['setup-plus', 'preparationSeconds', 1]
]) {
  document.getElementById(id).addEventListener('click', () => {
    timer.configure({ [field]: timer[field] + delta });
    saveSettings();
  });
}

window.addEventListener('beforeinstallprompt', event => {
  event.preventDefault();
  deferredInstall = event;
});
installButton.addEventListener('click', async () => {
  if (deferredInstall) {
    deferredInstall.prompt();
    await deferredInstall.userChoice;
    deferredInstall = null;
  } else {
    showToast('Use your browser menu to add Hangbeat to the home screen');
  }
});
window.addEventListener('appinstalled', () => { installButton.hidden = true; });
if (window.matchMedia('(display-mode: standalone)').matches || navigator.standalone) installButton.hidden = true;
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && timer.running) requestWakeLock();
});
if (import.meta.env.DEV && 'serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(registrations => {
    for (const registration of registrations) registration.unregister();
  }).catch(() => {});
}
