// The voices of the tower hall of mission two, made from nothing but arithmetic: the deep
// hum of the hall (a loop), a valve that lets off pressure, and something that knocks
// from inside a tower.
// Run: node tools/make_hall_sounds.js assets/sounds
const path = require('path');
const wav = require('./wav_lib.js');

const out = process.argv[2] || 'assets/sounds';
const RATE = 22050;

// The same dice every time: the files do not change from run to run.
let state = 71031;
function dice() {
  state = (state * 1664525 + 1013904223) >>> 0;
  return state / 4294967296;
}
function noise(frames) {
  const x = new Float32Array(frames);
  for (let i = 0; i < frames; i++) x[i] = dice() * 2 - 1;
  return x;
}
function lowpass(x, cutoff, poles = 2) {
  const k = 1 - Math.exp(-2 * Math.PI * cutoff / RATE);
  let y = x;
  for (let p = 0; p < poles; p++) {
    const next = new Float32Array(y.length);
    let last = 0;
    for (let i = 0; i < y.length; i++) { last += k * (y[i] - last); next[i] = last; }
    y = next;
  }
  return y;
}
function highpass(x, cutoff) {
  const low = lowpass(x, cutoff, 1);
  const y = new Float32Array(x.length);
  for (let i = 0; i < x.length; i++) y[i] = x[i] - low[i];
  return y;
}
function level(x, peak) {
  let most = 0;
  for (let i = 0; i < x.length; i++) most = Math.max(most, Math.abs(x[i]));
  const y = new Float32Array(x.length);
  for (let i = 0; i < x.length; i++) y[i] = x[i] / Math.max(most, 1e-9) * peak;
  return y;
}
// Makes the end of a sound run into its beginning: the last `seconds` fade into the first.
function seamless(x, seconds) {
  const lap = Math.floor(seconds * RATE);
  const frames = x.length - lap;
  const y = new Float32Array(frames);
  for (let i = 0; i < frames; i++) y[i] = x[i];
  for (let i = 0; i < lap; i++) {
    const t = i / lap;
    y[i] = x[i] * Math.sqrt(t) + x[frames + i] * Math.sqrt(1 - t);
  }
  return y;
}
// A few echoes off steel and concrete.
function room(x, taps, tail) {
  const y = new Float32Array(x.length + Math.floor(tail * RATE));
  for (let i = 0; i < x.length; i++) y[i] = x[i];
  for (const [delay, gain] of taps) {
    const shift = Math.floor(delay * RATE);
    for (let i = 0; i + shift < y.length; i++) y[i + shift] += y[i] * gain;
  }
  return y;
}
function save(name, samples) {
  const file = path.join(out, name + '.wav');
  wav.write(file, { rate: RATE, channels: [samples] });
  console.log('wrote', file, (samples.length / RATE).toFixed(2) + ' s');
}

// --- the hum of the hall: six seconds that run round. Every tone fits a whole number of
// times into them; the rumble under it is noise whose end runs into its beginning.
{
  const seconds = 6;
  const frames = seconds * RATE;
  const tones = [[41, 0.5, 0.0], [41.5, 0.42, 1.3], [55, 0.3, 0.4], [82.5, 0.2, 2.2], [123, 0.09, 0.9], [164.5, 0.05, 3.1]];
  const hum = new Float32Array(frames);
  for (let i = 0; i < frames; i++) {
    const t = i / RATE;
    let v = 0;
    for (const [pitch, gain, phase] of tones) v += gain * Math.sin(2 * Math.PI * pitch * t + phase);
    // A slow breath, once in the six seconds, and a faster flutter.
    hum[i] = v * (0.82 + 0.18 * Math.sin(2 * Math.PI * t / seconds)) * (0.94 + 0.06 * Math.sin(2 * Math.PI * 3.5 * t));
  }
  const rumble = seamless(level(lowpass(noise(frames + RATE), 90, 3), 1), 1);
  const air = seamless(level(highpass(lowpass(noise(frames + RATE), 900, 2), 300), 1), 1);
  const mix = new Float32Array(frames);
  for (let i = 0; i < frames; i++) mix[i] = hum[i] + 0.55 * rumble[i] + 0.05 * air[i];
  save('hive_deep', level(mix, 0.8));
}

// --- a valve lets off pressure: a hiss that starts hard, thins and dies away.
{
  const frames = Math.floor(1.9 * RATE);
  const raw = noise(frames);
  const bright = highpass(lowpass(raw, 6500, 2), 1800);
  const body = highpass(lowpass(raw, 2400, 2), 700);
  const hiss = new Float32Array(frames);
  for (let i = 0; i < frames; i++) {
    const t = i / RATE;
    const attack = Math.min(1, t / 0.012);
    const fall = Math.exp(-t * 2.4);
    const sputter = t > 1.0 ? 0.6 + 0.4 * Math.sin(2 * Math.PI * (14 + 30 * (t - 1.0)) * t) : 1.0;
    hiss[i] = attack * fall * sputter * (bright[i] * (0.4 + 0.6 * Math.exp(-t * 1.5)) + body[i] * 0.7);
  }
  // The clack of the valve itself.
  for (let i = 0; i < Math.floor(0.03 * RATE); i++) {
    const t = i / RATE;
    hiss[i] += 0.5 * Math.exp(-t * 160) * Math.sin(2 * Math.PI * 310 * t);
  }
  save('hive_hiss', level(room(hiss, [[0.047, 0.22], [0.113, 0.14], [0.21, 0.08]], 0.5), 0.75));
}

// --- something knocks from inside a tower: three dull blows on thick steel, not quite in time.
{
  const frames = Math.floor(1.3 * RATE);
  const knock = new Float32Array(frames);
  const blows = [[0.02, 1.0], [0.36, 0.72], [0.6, 0.9]];
  for (const [at, force] of blows) {
    const start = Math.floor(at * RATE);
    const drift = 0.97 + dice() * 0.06;
    for (let i = 0; start + i < frames && i < Math.floor(0.6 * RATE); i++) {
      const t = i / RATE;
      let v = Math.exp(-t * 26) * Math.sin(2 * Math.PI * 74 * drift * t);
      v += 0.5 * Math.exp(-t * 34) * Math.sin(2 * Math.PI * 131 * drift * t + 0.6);
      v += 0.16 * Math.exp(-t * 9) * Math.sin(2 * Math.PI * 393 * drift * t);
      v += 0.07 * Math.exp(-t * 7) * Math.sin(2 * Math.PI * 611 * drift * t + 1.1);
      v += 0.5 * Math.exp(-t * 240) * (dice() * 2 - 1);
      knock[start + i] += force * v;
    }
  }
  // Heard through the wall of the tower: dull.
  save('hive_knock', level(room(lowpass(knock, 900, 2), [[0.061, 0.3], [0.137, 0.2], [0.29, 0.12], [0.43, 0.07]], 0.7), 0.85));
}
