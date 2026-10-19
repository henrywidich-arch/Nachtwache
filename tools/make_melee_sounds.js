// Builds the blows of the melee weapons from the game's own sounds and a little synthesis:
//   melee_heavy_1..3  a sledgehammer or a crowbar landing: a deep thump you feel, the knock
//                     of the blow, bone giving way and the wet after it
//   melee_blade_1..3  a machete, an axe or a knife biting in: a sharp chop, a wet tear
//   swing_heavy_1..2  a heavy weapon coming round: a low, long rush of air
//   node tools/make_melee_sounds.js <sounds folder> <output folder>
// <sounds folder> is assets/sounds (it reads melee_*, thud_*, gib_*, squish and swipe there).
// The files are 48 kHz mono, 16 bit, peaking at -1 dB; how loud each is played is set in the
// mix table of scripts/sound.gd. Always the same noise: the files do not change between runs.
const path = require('path');
const wav = require('./wav_lib.js');

const [inDir, outDir] = process.argv.slice(2);
const RATE = 48000;

function load(name) {
  const sound = wav.read(path.join(inDir, name + '.wav'));
  return resample(wav.mono(sound), sound.rate, RATE);
}
// Also a change of pitch: `speed` below 1 plays it slower and lower.
function resample(x, from, to, speed = 1) {
  const step = from / to * speed;
  const out = new Float32Array(Math.floor(x.length / step));
  for (let i = 0; i < out.length; i++) {
    const at = i * step;
    const a = Math.floor(at);
    const b = Math.min(x.length - 1, a + 1);
    out[i] = x[a] + (x[b] - x[a]) * (at - a);
  }
  return out;
}
function noiseSource(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 2147483648 - 1; };
}
// A second-order filter (the usual "cookbook" forms). kind: 'low', 'high' or 'band'.
function filter(x, kind, cutoff, q = 0.707) {
  const w = 2 * Math.PI * Math.min(cutoff, RATE * 0.45) / RATE;
  const alpha = Math.sin(w) / (2 * q);
  const cos = Math.cos(w);
  let b0, b1, b2;
  if (kind === 'low') { b0 = (1 - cos) / 2; b1 = 1 - cos; b2 = (1 - cos) / 2; }
  else if (kind === 'high') { b0 = (1 + cos) / 2; b1 = -(1 + cos); b2 = (1 + cos) / 2; }
  else { b0 = alpha; b1 = 0; b2 = -alpha; }
  const a0 = 1 + alpha, a1 = -2 * cos, a2 = 1 - alpha;
  const y = new Float32Array(x.length);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < x.length; i++) {
    const v = (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
    x2 = x1; x1 = x[i]; y2 = y1; y1 = v; y[i] = v;
  }
  return y;
}
// A band of noise whose middle glides from `from` to `to` Hz, under an envelope.
function sweep(seconds, from, to, q, envelope, seed) {
  const n = Math.floor(seconds * RATE);
  const noise = noiseSource(seed);
  const out = new Float32Array(n);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < n; i++) {
    const t = i / n;
    const f = from * Math.pow(to / from, t);
    const w = 2 * Math.PI * f / RATE;
    const alpha = Math.sin(w) / (2 * q);
    const cos = Math.cos(w);
    const x = noise();
    const v = (alpha * x - alpha * x2 + 2 * cos * y1 - (1 - alpha) * y2) / (1 + alpha);
    x2 = x1; x1 = x; y2 = y1; y1 = v;
    out[i] = v * envelope(t);
  }
  return out;
}
// A deep thump: a sine that falls in pitch and dies away, with a click at its start.
function thump(seconds, high, low, decay) {
  const n = Math.floor(seconds * RATE);
  const out = new Float32Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    const f = low + (high - low) * Math.exp(-t * 28);
    phase += 2 * Math.PI * f / RATE;
    const attack = Math.min(1, t / 0.0015);
    out[i] = Math.sin(phase) * attack * Math.exp(-t / decay);
  }
  return out;
}
// Bone giving way: a run of short, hard cracks.
function crunch(count, spread, seed) {
  const noise = noiseSource(seed);
  const out = new Float32Array(Math.floor((spread + 0.03) * RATE));
  for (let k = 0; k < count; k++) {
    const at = Math.floor((k === 0 ? 0 : Math.pow((noise() + 1) / 2, 1.6) * spread) * RATE);
    const length = Math.floor((0.003 + (noise() + 1) * 0.004) * RATE);
    const level = (k === 0 ? 1 : 0.35 + (noise() + 1) * 0.3);
    for (let i = 0; i < length && at + i < out.length; i++) out[at + i] += noise() * level * Math.exp(-i / (length * 0.3));
  }
  return filter(filter(out, 'high', 1400), 'low', 7000);
}
function mix(length, layers) {
  const out = new Float32Array(Math.floor(length * RATE));
  for (const [x, gain, start = 0] of layers) {
    const offset = Math.floor(start * RATE);
    for (let i = 0; i < x.length && i + offset < out.length; i++) out[i + offset] += x[i] * gain;
  }
  return out;
}
function finish(x, fade) {
  const n = x.length;
  const tail = Math.floor(fade * RATE);
  for (let i = 0; i < tail; i++) x[n - 1 - i] *= i / tail;
  let peak = 0;
  for (const v of x) peak = Math.max(peak, Math.abs(v));
  const gain = Math.pow(10, -1 / 20) / Math.max(peak, 1e-6);
  return x.map(v => v * gain);
}
function save(name, x) {
  wav.write(path.join(outDir, name + '.wav'), { rate: RATE, channels: [x] });
  console.log('wrote', name);
}
function quieter(x, gain) { return x.map(v => v * gain); }

const butt = [load('melee_1'), load('melee_2'), load('melee_3')];
const thuds = [load('thud_1'), load('thud_2')];
const gibs = [load('gib_1'), load('gib_2'), load('gib_3')];
const squish = load('squish');
const swipe = load('swipe');

for (let k = 0; k < 3; k++) {
  const knock = resample(butt[k], RATE, RATE, 0.78 + k * 0.05);
  const body = filter(resample(thuds[k % 2], RATE, RATE, 0.85), 'low', 900);
  const wet = filter(resample(gibs[k], RATE, RATE, 0.82), 'low', 3500);
  save(`melee_heavy_${k + 1}`, finish(mix(0.75, [
    [thump(0.6, 140 - k * 12, 42 - k * 3, 0.16), 1.0],
    [knock, 0.9],
    [body, 0.7],
    [crunch(9 + k * 3, 0.07 + k * 0.015, 911 + k * 37), 0.55, 0.004],
    [wet, 0.6, 0.02]
  ]), 0.2));
}
for (let k = 0; k < 3; k++) {
  const chop = filter(resample(butt[(k + 1) % 3], RATE, RATE, 1.2 + k * 0.06), 'high', 500);
  const tear = sweep(0.22 + k * 0.03, 3200 - k * 300, 500, 1.4, t => Math.pow(1 - t, 1.6) * Math.min(1, t * 40), 4242 + k * 13);
  const wet = filter(resample(k === 2 ? squish : gibs[(k + 1) % 3], RATE, RATE, 0.95 + k * 0.05), 'low', 5000);
  save(`melee_blade_${k + 1}`, finish(mix(0.6, [
    [crunch(2 + k, 0.02, 77 + k), 0.9],
    [chop, 0.65],
    [thump(0.25, 220, 80, 0.05), 0.5],
    [tear, 0.8, 0.01],
    [quieter(wet, 1.0), 0.55, 0.025]
  ]), 0.15));
}
for (let k = 0; k < 2; k++) {
  const air = sweep(0.5 + k * 0.08, 260, 900 + k * 120, 0.9, t => Math.pow(Math.sin(Math.PI * Math.pow(t, 0.75)), 2), 515 + k * 3);
  const low = filter(resample(swipe, RATE, RATE, 0.62 - k * 0.06), 'low', 1600);
  save(`swing_heavy_${k + 1}`, finish(mix(0.62 + k * 0.08, [[air, 1.0], [low, 0.8, 0.02]]), 0.12));
}
