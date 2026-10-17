// How lively does a recording sound, in numbers (nobody listens to it: no sound on the PC).
//   node tools/voice_probe.js <file.mp3|ogg|wav> [more files ...]
// Prints per file: seconds, mean pitch (Hz), pitch spread (standard deviation in semitones, over the voiced
// frames), pitch range (10th to 90th percentile, semitones), loudness spread (standard deviation in dB of the
// speech frames), speech share (frames over the gate), the longest pause inside the speech.
// A flat, monotone reading has a pitch spread under about 1.5 semitones; a lively one 2.5 and more; over
// about 5 it is usually acted too hard or broken.
const { spawnSync } = require('child_process');
const FFMPEG = process.env.FFMPEG || 'C:/Users/bitef/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-9.0.2-full_build/bin/ffmpeg.exe';
const SR = 16000;
function decode(file) {
  const r = spawnSync(FFMPEG, ['-hide_banner', '-loglevel', 'error', '-i', file, '-ac', '1', '-ar', String(SR), '-f', 'f32le', '-'], { maxBuffer: 1 << 28 });
  if (r.status !== 0) throw new Error('ffmpeg: ' + r.stderr);
  const b = r.stdout;
  return new Float32Array(b.buffer, b.byteOffset, Math.floor(b.length / 4));
}
function pitch(x, from, n) {
  // normalised autocorrelation, lags for 70..400 Hz
  const minLag = Math.floor(SR / 400), maxLag = Math.floor(SR / 70);
  let energy = 0;
  for (let i = 0; i < n; i++) energy += x[from + i] * x[from + i];
  if (energy < 1e-6) return null;
  let best = 0, bestLag = 0;
  const vals = new Float32Array(maxLag + 1);
  for (let lag = minLag; lag <= maxLag; lag++) {
    let s = 0, e2 = 0;
    for (let i = 0; i + lag < n; i++) { s += x[from + i] * x[from + i + lag]; e2 += x[from + i + lag] * x[from + i + lag]; }
    const c = s / Math.sqrt(energy * e2 + 1e-12);
    vals[lag] = c;
    if (c > best) { best = c; bestLag = lag; }
  }
  if (best < 0.55) return null;
  // prefer the shortest lag that is nearly as good (avoids octave errors downwards)
  for (let lag = minLag; lag < bestLag; lag++) if (vals[lag] > best * 0.93 && vals[lag] >= vals[lag - 1] && vals[lag] >= vals[lag + 1]) return SR / lag;
  return SR / bestLag;
}
function probe(file) {
  const x = decode(file);
  const win = Math.floor(SR * 0.04), hop = Math.floor(SR * 0.01);
  const dbs = [], f0 = [], frames = [];
  for (let s = 0; s + win <= x.length; s += hop) {
    let e = 0;
    for (let i = 0; i < win; i++) e += x[s + i] * x[s + i];
    const db = 10 * Math.log10(e / win + 1e-12);
    frames.push(db);
  }
  const peak = Math.max(...frames);
  const gate = peak - 35;
  let speech = 0, run = 0, longest = 0, started = false, lastSpeech = -1;
  frames.forEach((db, k) => {
    if (db > gate) {
      speech++;
      if (started && run > 0) longest = Math.max(longest, run);
      run = 0; started = true; lastSpeech = k;
      dbs.push(db);
      const p = pitch(x, k * hop, win);
      if (p) f0.push(Math.log2(p) * 12);
    } else if (started) run++;
  });
  const mean = (a) => a.reduce((s, v) => s + v, 0) / Math.max(1, a.length);
  const sd = (a) => { const m = mean(a); return Math.sqrt(mean(a.map((v) => (v - m) * (v - m)))); };
  const sorted = f0.slice().sort((a, b) => a - b);
  const pc = (p) => sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))] : 0;
  return {
    seconds: +(x.length / SR).toFixed(2),
    f0_hz: Math.round(Math.pow(2, mean(f0) / 12)),
    pitch_sd_st: +sd(f0).toFixed(2),
    pitch_range_st: +(pc(0.9) - pc(0.1)).toFixed(2),
    loud_sd_db: +sd(dbs).toFixed(2),
    voiced: +(f0.length / Math.max(1, speech)).toFixed(2),
    speech: +(speech / frames.length).toFixed(2),
    pause_s: +(longest * 0.01).toFixed(2)
  };
}
module.exports = { probe };
if (require.main === module) {
  for (const file of process.argv.slice(2)) console.log(file.split(/[\\/]/).pop().slice(0, 60).padEnd(60), JSON.stringify(probe(file)));
}
