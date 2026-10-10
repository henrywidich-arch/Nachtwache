// Builds the sounds of the Crusher's shell (scripts/infected.gd, SHELL_SECONDS) by synthesis:
//   crusher_shell_tell   plates grind and creep over the skin - the warning, a second long
//   crusher_shell_on     the shell shuts: a deep blow, and stone that rings
//   crusher_shell_off    it breaks up: the plates crack and fall off
//   hit_shell            what the shooter hears when his bullet lands on the shell: a dull
//                        knock in place of the ding, so that he hears it is wasted
//   node tools/make_crusher_sounds.js <output folder>
// Nothing is recorded and nothing is taken from anywhere. 44.1 kHz mono, 16 bit; how loud
// each is played is set in FieldAudio.MIX.
const path = require('path');
const wav = require('./wav_lib.js');

const outDir = process.argv[2];
if (!outDir) { console.error('usage: node tools/make_crusher_sounds.js <output folder>'); process.exit(1); }
const RATE = 44100;

// Always the same noise, so that the files do not change from run to run.
function dice(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}
function buffer(seconds) { return new Float32Array(Math.round(seconds * RATE)); }

// A second-order filter in place ('low', 'high' or 'band').
function filter(x, kind, cutoff, q = 0.707) {
  const w = 2 * Math.PI * Math.min(cutoff, RATE * 0.45) / RATE;
  const alpha = Math.sin(w) / (2 * q);
  const cos = Math.cos(w);
  let b0, b1, b2;
  if (kind === 'low') { b0 = (1 - cos) / 2; b1 = 1 - cos; b2 = b0; }
  else if (kind === 'high') { b0 = (1 + cos) / 2; b1 = -(1 + cos); b2 = b0; }
  else { b0 = alpha; b1 = 0; b2 = -alpha; }
  const a0 = 1 + alpha, a1 = -2 * cos, a2 = 1 - alpha;
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < x.length; i++) {
    const y = (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
    x2 = x1; x1 = x[i]; y2 = y1; y1 = y; x[i] = y;
  }
  return x;
}
// A short burst of filtered noise that dies away at `decay` (1/s).
function grain(rand, seconds, kind, cutoff, q, decay) {
  const g = buffer(seconds);
  for (let i = 0; i < g.length; i++) g[i] = rand() * 2 - 1;
  filter(g, kind, cutoff, q);
  for (let i = 0; i < g.length; i++) g[i] *= Math.exp(-decay * i / RATE) * Math.min(1, i / (0.0006 * RATE));
  return g;
}
// A tone that glides from one pitch to another and dies away; `rise` (s) is how fast it sets in.
function tone(out, at, seconds, from, to, level, decay, rise = 0.002) {
  const start = Math.round(at * RATE);
  const length = Math.min(out.length - start, Math.round(seconds * RATE));
  let phase = 0;
  for (let i = 0; i < length; i++) {
    const t = i / RATE;
    phase += 2 * Math.PI * (from + (to - from) * (t / seconds)) / RATE;
    out[start + i] += Math.sin(phase) * level * Math.exp(-decay * t) * Math.min(1, t / rise);
  }
}
function add(out, at, piece, level = 1) {
  const start = Math.round(at * RATE);
  for (let i = 0; i < piece.length && start + i < out.length; i++) out[start + i] += piece[i] * level;
}
// To a peak of `db`, with the ends faded.
function finish(x, db = -1.5) {
  let peak = 0;
  for (let i = 0; i < x.length; i++) peak = Math.max(peak, Math.abs(x[i]));
  const gain = Math.pow(10, db / 20) / Math.max(peak, 1e-6);
  const fade = Math.round(0.012 * RATE);
  for (let i = 0; i < x.length; i++) x[i] *= gain * Math.min(1, i / 40) * Math.min(1, (x.length - 1 - i) / fade);
  return x;
}
function save(name, samples) {
  wav.write(path.join(outDir, name + '.wav'), { rate: RATE, channels: [samples] });
  console.log(name, (samples.length / RATE).toFixed(2) + ' s');
}

// The warning: stone grinds on stone, closer and higher from creak to creak, over a hum
// that climbs. It swells to its end, where the blow of the shell shutting follows.
function tell() {
  const rand = dice(4101);
  const out = buffer(1.05);
  for (let k = 0; k < 46; k++) {
    const t = Math.pow(k / 46, 0.8);
    const at = t * 0.95 + rand() * 0.012;
    add(out, at, grain(rand, 0.05, 'band', 420 + 1900 * t + rand() * 300, 3.5, 70), 0.25 + 0.75 * t);
  }
  const hum = buffer(1.05);
  tone(hum, 0, 1.05, 62, 128, 0.9, 0, 0.05);
  tone(hum, 0, 1.05, 93, 197, 0.45, 0, 0.05);
  for (let i = 0; i < hum.length; i++) {
    const t = i / RATE;
    out[i] += hum[i] * (0.1 + 0.9 * t * t) * (0.7 + 0.3 * Math.sin(2 * Math.PI * 23 * t));
  }
  return finish(out, -2);
}

// The shell shuts: a deep blow, a crack, and stone plates that ring out of tune and briefly.
function shut() {
  const rand = dice(4102);
  const out = buffer(0.95);
  tone(out, 0, 0.6, 118, 44, 1.0, 7);
  tone(out, 0, 0.3, 236, 90, 0.4, 14);
  add(out, 0, filter(grain(rand, 0.09, 'high', 2400, 0.7, 55), 'low', 7000), 0.55);
  for (const [freq, level, decay] of [[318, 0.42, 7], [487, 0.34, 9], [742, 0.26, 11], [1163, 0.2, 15], [1790, 0.13, 20], [2610, 0.08, 26]]) {
    tone(out, 0.004, 0.9, freq, freq * 0.985, level, decay, 0.0006);
  }
  return finish(out, -1.5);
}

// It breaks up: plates crack one after the other, most of them at once, chips fall, and
// what was held in goes out as a breath.
function open() {
  const rand = dice(4103);
  const out = buffer(1.1);
  tone(out, 0, 0.35, 150, 70, 0.6, 12);
  for (let k = 0; k < 70; k++) {
    const at = Math.pow(rand(), 1.9) * 0.85;
    add(out, at, grain(rand, 0.03, 'band', 1100 + rand() * 4200, 2.2, 110 + rand() * 120), (0.22 + rand() * 0.5) * (1 - at * 0.7));
  }
  for (const at of [0.0, 0.07, 0.19, 0.34]) add(out, at, grain(rand, 0.06, 'band', 520 + rand() * 300, 4, 60), 0.6);
  const breath = buffer(1.1);
  for (let i = 0; i < breath.length; i++) breath[i] = (rand() * 2 - 1) * Math.exp(-3.4 * i / RATE) * Math.min(1, i / (0.03 * RATE));
  add(out, 0, filter(filter(breath, 'high', 1500), 'low', 6000), 0.2);
  return finish(out, -2);
}

// The shooter's answer: a knock on something thick, low and dead - no ring, no tail.
function knock() {
  const rand = dice(4104);
  const out = buffer(0.15);
  tone(out, 0, 0.14, 250, 165, 1.0, 42, 0.0008);
  tone(out, 0, 0.1, 415, 330, 0.4, 70, 0.0008);
  add(out, 0, grain(rand, 0.03, 'low', 1300, 0.7, 130), 0.55);
  return finish(out, -1.5);
}

save('crusher_shell_tell', tell());
save('crusher_shell_on', shut());
save('crusher_shell_off', open());
save('hit_shell', knock());
