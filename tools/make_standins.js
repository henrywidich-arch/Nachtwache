// Stand-in sounds for what has no recording of its own yet: the four new guns, the blow
// with the weapon, the Molotov cocktail, burning ground and the flamethrower. They are
// made from recordings the game already has (pitched, cut and layered) and, for the two
// fires, from shaped noise. A recorded file of the same name simply replaces one of these.
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

const sniper = load('sniper');
const shotgun = load('shotgun');
const revolver = load('revolver');
const ak = load('ak');
const blast = load('explosion_1');

// The M14: the crack of the sniper rifle, higher and shorter, over the body of the AK's shot.
save('m14', cut(mix([[pitch(sniper, 1.22), 1.0], [pitch(ak, 0.92), 0.55]]), 0.95, 0.25));
// The SVD: the same crack, a little higher than the bolt-action rifle's.
save('svd', cut(mix([[pitch(sniper, 1.1), 1.0], [pitch(ak, 0.85), 0.3]]), 1.2, 0.3));
// The .50: far deeper, with the thump of a blast under it and a long tail.
save('fifty', cut(mix([[pitch(sniper, 0.74), 1.0], [lowpass(pitch(blast, 1.1), 260), 0.8], [pitch(revolver, 0.7), 0.35]]), 2.0, 0.6));
// The double rifle: the boom of a shotgun and of a magnum together, pitched down.
save('nitro', cut(mix([[pitch(shotgun, 0.82), 1.0], [pitch(revolver, 0.78), 0.8], [lowpass(pitch(blast, 1.3), 220), 0.45]]), 1.4, 0.4));
// A blow with the weapon: a short dull thud and the rattle of gear.
save('melee', cut(mix([[pitch(load('thud_1'), 1.35), 1.0], [pitch(load('hit'), 0.8), 0.5], [pitch(load('mag_in'), 0.9), 0.3, 0.03]]), 0.45, 0.15), 0.8);

// The Molotov cocktail: glass, then the petrol catches.
{
  const glass = highpass(mix([[pitch(load('shell_in_1'), 2.4), 1.0], [pitch(load('shell_in_2'), 3.1), 0.8, 0.04], [pitch(load('shell_in_3'), 2.0), 0.7, 0.09], [pitch(load('click'), 1.8), 0.5]]), 1500);
  const whoosh = lowpass(noise(1.5), 900, 2);
  for (let i = 0; i < whoosh.length; i++) {
    const t = i / RATE;
    whoosh[i] *= Math.min(1, t / 0.12) * Math.exp(-t * 2.4);
  }
  save('molotov', cut(mix([[glass, 0.9], [pitch(load('pop_1'), 0.7), 0.8, 0.05], [whoosh, 1.0, 0.08]]), 1.6, 0.4));
}

// Fire on the ground: a low rumble that flutters, and wood that snaps.
{
  const seconds = 4.0;
  const total = seconds + 0.5;
  const rumble = lowpass(noise(total), 420, 2);
  const hissing = highpass(lowpass(noise(total), 3800, 1), 900);
  const out = new Float32Array(rumble.length);
  let flutter = 0.7;
  for (let i = 0; i < out.length; i++) {
    if (i % 1200 === 0) flutter = 0.55 + random() * 0.45;
    out[i] = rumble[i] * 2.4 * flutter + hissing[i] * 0.22;
  }
  // Snaps: a few a second, each a tiny burst of noise that dies at once.
  for (let k = 0; k < total * 7; k++) {
    const at = Math.floor(random() * (out.length - 2000));
    const strength = 0.25 + random() * 0.75;
    const length = 120 + Math.floor(random() * 500);
    for (let i = 0; i < length; i++) out[at + i] += (random() * 2 - 1) * strength * Math.exp(-i / (length * 0.22));
  }
  save('fire', loop(out, seconds), 0.7);
}

// The flamethrower: gas under pressure, a roar with a fast flutter in it.
{
  const seconds = 3.0;
  const total = seconds + 0.5;
  const roar = highpass(lowpass(noise(total), 1500, 2), 140);
  const jet = highpass(lowpass(noise(total), 5200, 1), 1800);
  const deep = lowpass(noise(total), 160, 2);
  const out = new Float32Array(roar.length);
  for (let i = 0; i < out.length; i++) {
    const t = i / RATE;
    const flutter = 0.82 + 0.18 * Math.sin(t * 2 * Math.PI * 11) * Math.sin(t * 2 * Math.PI * 1.7 + 1);
    out[i] = (roar[i] * 1.5 + jet[i] * 0.5 + deep[i] * 3.0) * flutter;
  }
  save('flamer', loop(out, seconds), 0.75);
}
