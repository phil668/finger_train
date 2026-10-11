import { RepeaterTimer } from './src/timer.js';
import { TrainingLog, calendarDays, formatHang, localDayKey, monthSummary } from './src/training.js';
import { MaxHangTest, formatStopwatch } from './src/max-hang.js';

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
const trainingLog = new TrainingLog();
const maxHang = new MaxHangTest();
let lastLoggedSets = 0;
let maxAttemptSaved = false;
let activeTab = 'timer';
let calendarMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
let selectedDay = localDayKey();

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
      if (!timer.running && !maxHang.running) releaseWakeLock();
    }
  } catch { /* Not all browsers support keeping the display awake. */ }
}

function releaseWakeLock() {
  wakeLock?.release().catch(() => {});
  wakeLock = null;
}

function updateView() {
  if (!timer) return;
  if (timer.completedSets < lastLoggedSets) lastLoggedSets = timer.completedSets;
  if (timer.phase === 'setComplete' && timer.completedSets > lastLoggedSets) {
    trainingLog.addRepeater(timer.repetitionsPerSet);
    lastLoggedSets = timer.completedSets;
    if (activeTab === 'dashboard') renderDashboard();
  }
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
  if (!timer.running && !maxHang.running && wakeLock) releaseWakeLock();
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
  if (!maxHang.running) releaseWakeLock();
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
  if (document.visibilityState === 'visible' && (timer.running || maxHang.running)) requestWakeLock();
});
if (import.meta.env.DEV && 'serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(registrations => {
    for (const registration of registrations) registration.unregister();
  }).catch(() => {});
}

function renderDashboard() {
  const year = calendarMonth.getFullYear();
  const month = calendarMonth.getMonth();
  const summary = monthSummary(trainingLog.records, year, month);
  document.getElementById('stat-days').textContent = summary.days;
  document.getElementById('stat-sets').textContent = summary.sets;
  document.getElementById('stat-best').textContent = summary.bestHangMs ? formatHang(summary.bestHangMs) : '—';
  document.getElementById('calendar-title').textContent = calendarMonth.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

  const recordsByDay = new Map();
  for (const record of trainingLog.records) {
    if (!recordsByDay.has(record.day)) recordsByDay.set(record.day, []);
    recordsByDay.get(record.day).push(record);
  }

  const cells = calendarDays(year, month).map(day => {
    if (day === null) {
      const spacer = document.createElement('span');
      spacer.className = 'calendar-spacer';
      return spacer;
    }
    const date = new Date(year, month, day);
    const key = localDayKey(date);
    const records = recordsByDay.get(key) ?? [];
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'calendar-day';
    if (key === localDayKey()) button.classList.add('today');
    if (key === selectedDay) button.classList.add('selected');
    button.setAttribute('aria-pressed', String(key === selectedDay));
    button.setAttribute('aria-label', `${date.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}, ${records.length} activities`);
    const number = document.createElement('span');
    number.textContent = day;
    button.append(number);
    const dots = document.createElement('span');
    dots.className = 'calendar-dots';
    if (records.some(record => record.type === 'repeater')) {
      const dot = document.createElement('i');
      dot.className = 'legend-dot repeater-dot';
      dots.append(dot);
    }
    if (records.some(record => record.type === 'maxHang')) {
      const dot = document.createElement('i');
      dot.className = 'legend-dot hang-dot';
      dots.append(dot);
    }
    button.append(dots);
    button.addEventListener('click', () => {
      selectedDay = key;
      renderDashboard();
    });
    return button;
  });
  document.getElementById('calendar-grid').replaceChildren(...cells);

  const [selectedYear, selectedMonth, selectedDate] = selectedDay.split('-').map(Number);
  const selected = new Date(selectedYear, selectedMonth - 1, selectedDate);
  document.getElementById('selected-day-title').textContent = selected.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' });
  const events = (recordsByDay.get(selectedDay) ?? []).slice().sort((a, b) => b.at.localeCompare(a.at));
  const eventElements = events.map(record => {
    const item = document.createElement('div');
    item.className = `day-event ${record.type}`;
    const label = document.createElement('span');
    label.textContent = record.type === 'repeater' ? `${record.repetitions} × 7/3 hangs` : `Max hang · ${formatHang(record.durationMs)}`;
    const time = document.createElement('time');
    time.dateTime = record.at;
    time.textContent = new Date(record.at).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
    item.append(label, time);
    return item;
  });
  if (!eventElements.length) {
    const empty = document.createElement('p');
    empty.className = 'empty-day';
    empty.textContent = 'No training logged for this day.';
    eventElements.push(empty);
  }
  document.getElementById('selected-day-events').replaceChildren(...eventElements);
}

function renderMaxHang() {
  const running = maxHang.running;
  document.getElementById('max-timer').className = `max-timer ${maxHang.phase}`;
  document.getElementById('max-timer').setAttribute('aria-label', `Max hang ${maxHang.phase}, ${(maxHang.elapsedMs / 1000).toFixed(1)} seconds`);
  document.getElementById('max-phase').textContent = running ? 'HANGING' : maxHang.phase === 'result' ? 'RESULT' : 'READY';
  document.getElementById('max-time').textContent = formatStopwatch(maxHang.elapsedMs);
  document.getElementById('max-primary-icon').textContent = running ? '■' : '▶';
  document.getElementById('max-primary-label').textContent = running ? 'STOP & SAVE' : maxHang.phase === 'result' ? 'TRY AGAIN' : 'START HANG';
  document.getElementById('max-reset').disabled = maxHang.phase === 'ready';
  document.getElementById('max-reset').setAttribute('aria-label', running ? 'Cancel max hang test' : 'Reset max hang test');
  document.getElementById('max-status').textContent = running ? 'Stop when you let go of the edge' : maxHang.phase === 'result'
    ? maxAttemptSaved ? 'Saved to your training calendar' : 'Attempt too short to save'
    : 'Tap start when your fingers are on the edge';
  document.getElementById('max-best').textContent = trainingLog.bestHangMs ? formatHang(trainingLog.bestHangMs) : '—';
  document.getElementById('max-last').textContent = trainingLog.lastHangMs ? formatHang(trainingLog.lastHangMs) : '—';
  if (!running && !timer.running && wakeLock) releaseWakeLock();
}

function showTab(tab) {
  activeTab = ['timer', 'dashboard', 'max-hang'].includes(tab) ? tab : 'timer';
  for (const name of ['timer', 'dashboard', 'max-hang']) {
    document.getElementById(`screen-${name}`).hidden = name !== activeTab;
  }
  for (const button of document.querySelectorAll('.tab')) {
    const selected = button.dataset.tab === activeTab;
    button.classList.toggle('active', selected);
    if (selected) button.setAttribute('aria-current', 'page');
    else button.removeAttribute('aria-current');
  }
  if (activeTab === 'dashboard') renderDashboard();
  if (activeTab === 'max-hang') renderMaxHang();
  window.scrollTo(0, 0);
}

for (const button of document.querySelectorAll('.tab')) {
  button.addEventListener('click', () => {
    const tab = button.dataset.tab;
    if (location.hash !== `#${tab}`) location.hash = tab;
    showTab(tab);
  });
}
window.addEventListener('hashchange', () => showTab(location.hash.slice(1)));
showTab(location.hash.slice(1));

document.getElementById('month-prev').addEventListener('click', () => {
  calendarMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() - 1, 1);
  selectedDay = localDayKey(calendarMonth);
  renderDashboard();
});
document.getElementById('month-next').addEventListener('click', () => {
  calendarMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + 1, 1);
  selectedDay = localDayKey(calendarMonth);
  renderDashboard();
});
document.getElementById('calendar-today').addEventListener('click', () => {
  const today = new Date();
  calendarMonth = new Date(today.getFullYear(), today.getMonth(), 1);
  selectedDay = localDayKey(today);
  renderDashboard();
});

document.getElementById('max-primary').addEventListener('click', () => {
  if (maxHang.running) {
    const durationMs = maxHang.stop();
    maxAttemptSaved = durationMs >= 100;
    if (maxAttemptSaved) {
      trainingLog.addMaxHang(durationMs);
      if (activeTab === 'dashboard') renderDashboard();
    }
  } else {
    maxHang.start();
    maxAttemptSaved = false;
    requestWakeLock();
  }
  renderMaxHang();
});
document.getElementById('max-reset').addEventListener('click', () => {
  maxHang.reset();
  maxAttemptSaved = false;
  renderMaxHang();
});
setInterval(() => { if (maxHang.running && activeTab === 'max-hang') renderMaxHang(); }, 100);
renderMaxHang();
