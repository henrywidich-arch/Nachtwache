// Stand-in shot sounds for the MP7 (weapon "mp7"), until a recording replaces them: the
// shot is the P90 played a little higher and tighter, with the crack of the UMP under it;
// the silenced shot is the silenced UMP, higher and shorter, with the thud of the Badger.
// Both are made from recordings the game already has. A recorded file of the same name
// simply replaces them.
//   node tools/make_mp7_sounds.js <sounds folder>
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
function save(name, x, level = 0.89) {
  const p = wav.peak(x) || 1;
  const out = new Float32Array(x.length);
  for (let i = 0; i < x.length; i++) out[i] = x[i] / p * level;
  wav.write(path.join(dir, name + '.wav'), { rate: RATE, channels: [out] });
  console.log(name.padEnd(8), (x.length / RATE).toFixed(2) + ' s');
}


// The shot: short, high and sharp (4.6 mm, a short barrel), so it can be fired 950 times
// a minute without the tails running into each other.
save('mp7', cut(mix([[pitch(load('p90'), 1.12), 1.0], [highpass(pitch(load('ump'), 1.2), 900), 0.45, 0.002]]), 0.3, 0.12), 0.85);
// The silenced shot: a dull pop with a little mechanical clatter.
save('mp7_sil', cut(mix([[pitch(load('ump_sil'), 1.1), 1.0], [lowpass(pitch(load('badger'), 1.15), 2500), 0.4]]), 0.26, 0.1), 0.8);
