// Stand-in sounds for what has no recording of its own yet: the G36's shot (with and
// without suppressor) and the syringe. They are made from recordings the game already
// has (pitched, cut and layered). A recorded file of the same name simply replaces one
// of these; what got its recording since (the newer guns, the blow, the Molotov cocktail,
// fire and the flamethrower) is built by tools/make_sounds.js.
//   node tools/make_standins.js <sounds folder>
const fs = require('fs');
const path = require('path');
const wav = require('./wav_lib.js');

const dir = process.argv[2];
const RATE = 48000;
let seed = 20261004;
function random() {
  // Always the same noise, so that the files do not change from run to run.
  seed = (seed * 1664525 + 1013904223) >>> 0;
  return seed / 4294967296;
}

function load(name) {
  const sound = wav.read(path.join(dir, name + '.wav'));
  return resample(wav.mono(sound), sound.rate, RATE);
}
function resample(x, from, to) {
  if (from === to) return Float32Array.from(x);
  const out = new Float32Array(Math.floor(x.length * to / from));
  for (let i = 0; i < out.length; i++) {
    const at = i * from / to;
    const a = Math.floor(at);
    const b = Math.min(x.length - 1, a + 1);
    out[i] = x[a] + (x[b] - x[a]) * (at - a);
  }
  return out;
}
// Played faster (factor > 1: higher and shorter) or slower.
function pitch(x, factor) { return resample(x, RATE * factor, RATE); }
function cut(x, seconds, fade = 0.08) {
  const out = Float32Array.from(x.subarray(0, Math.min(x.length, Math.floor(seconds * RATE))));
  const tail = Math.min(out.length, Math.floor(fade * RATE));
  for (let i = 0; i < tail; i++) out[out.length - 1 - i] *= i / tail;
  return out;
}
function lowpass(x, cutoff, poles = 2) {
  const a = Math.exp(-2 * Math.PI * cutoff / RATE);
  let out = x;
  for (let p = 0; p < poles; p++) {
    const y = new Float32Array(out.length);
    let s = 0;
    for (let i = 0; i < out.length; i++) { s = (1 - a) * out[i] + a * s; y[i] = s; }
    out = y;
  }
  return out;
}
function highpass(x, cutoff) {
  const low = lowpass(x, cutoff, 1);
  const y = new Float32Array(x.length);
  for (let i = 0; i < x.length; i++) y[i] = x[i] - low[i];
  return y;
}
// Layers: [samples, gain, delay in seconds].
function mix(layers) {
  let length = 0;
  for (const [x, , delay = 0] of layers) length = Math.max(length, x.length + Math.floor(delay * RATE));
  const out = new Float32Array(length);
  for (const [x, gain, delay = 0] of layers) {
    const p = wav.peak(x) || 1;
    const at = Math.floor(delay * RATE);
    for (let i = 0; i < x.length; i++) out[at + i] += x[i] / p * gain;
  }
  return out;
}
function noise(seconds) {
  const out = new Float32Array(Math.floor(seconds * RATE));
  for (let i = 0; i < out.length; i++) out[i] = random() * 2 - 1;
  return out;
}
// The end is blended into the beginning, so that the sound can run in a loop.
function loop(x, seconds, blend = 0.4) {
  const n = Math.floor(seconds * RATE);
  const f = Math.floor(blend * RATE);
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) out[i] = x[i];
  for (let i = 0; i < f; i++) {
    const t = i / f;
    out[i] = x[i] * t + x[n + i] * (1 - t);
  }
  return out;
}
function save(name, x, level = 0.89) {
  const p = wav.peak(x) || 1;
  const out = new Float32Array(x.length);
  for (let i = 0; i < x.length; i++) out[i] = x[i] / p * level;
  wav.write(path.join(dir, name + '.wav'), { rate: RATE, channels: [out] });
  console.log(name.padEnd(8), (x.length / RATE).toFixed(2) + ' s');
}

// The G36: the carbine's crack a little lower, with the body of the UMP's shot and the
// clack of its action under it; suppressed, the Honey Badger's cough over the UMP's.
save('g36', cut(mix([[pitch(load('shot'), 0.92), 1.0], [pitch(load('ump'), 1.12), 0.4], [highpass(pitch(load('bolt'), 1.3), 900), 0.22, 0.03]]), 0.6, 0.22));
save('g36_sil', cut(mix([[pitch(load('badger'), 0.9), 1.0], [pitch(load('ump_sil'), 1.08), 0.5], [highpass(pitch(load('bolt'), 1.3), 900), 0.25, 0.03]]), 0.4, 0.15), 0.6);
// The syringe: a cap that snaps and the short hiss of the injector.
{
  const hiss = highpass(noise(0.4), 2500);
  for (let i = 0; i < hiss.length; i++) {
    const s = i / RATE;
    hiss[i] *= Math.min(1, s / 0.02) * Math.exp(-s * 9);
  }
  save('syringe', cut(mix([[pitch(load('equip'), 1.5), 0.8], [pitch(load('click'), 1.3), 0.6, 0.12], [hiss, 0.7, 0.16]]), 0.6, 0.2), 0.7);
}
