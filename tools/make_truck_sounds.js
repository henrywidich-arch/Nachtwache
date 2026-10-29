// The voices of the rocket launcher truck of the simulation hall (TokyoConvoy), made from
// arithmetic: the diesel of an 8x8 at idle and under way (a loop), its horn, and the
// hydraulics that lift the launcher.
// Run: node tools/make_truck_sounds.js assets/sounds
const path = require('path');
const wav = require('./wav_lib.js');

const out = process.argv[2] || 'assets/sounds';
const RATE = 22050;
let state = 80801;
function dice() {
  state = (state * 1664525 + 1013904223) >>> 0;
  return state / 4294967296;
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
function level(x, peak) {
  let most = 0;
  for (let i = 0; i < x.length; i++) most = Math.max(most, Math.abs(x[i]));
  const y = new Float32Array(x.length);
  for (let i = 0; i < x.length; i++) y[i] = x[i] / Math.max(most, 1e-9) * peak;
  return y;
}
function save(name, samples) {
  const file = path.join(out, name + '.wav');
  wav.write(file, { rate: RATE, channels: [samples] });
  console.log('wrote', file, (samples.length / RATE).toFixed(2) + ' s');
}

// --- the diesel: four seconds that run round. Eight cylinders fire 30 times a second (a
// whole number of times in the loop); each firing is a short dull knock, a little uneven,
// over a rumble of noise that is a whole number of periods of its own.
{
  const seconds = 4;
  const frames = seconds * RATE;
  const fire = 30;
  const x = new Float32Array(frames);
  const knocks = seconds * fire;
  for (let k = 0; k < knocks; k++) {
    const start = Math.floor(k * RATE / fire + (dice() - 0.5) * 30);
    const strength = 0.65 + 0.35 * dice() + (k % 8 === 0 ? 0.25 : 0);
    for (let i = 0; i < 420; i++) {
      const at = (start + i + frames) % frames;
      const t = i / RATE;
      x[at] += strength * Math.exp(-t * 55) * Math.sin(2 * Math.PI * (62 + 20 * dice()) * t);
    }
  }
  const grit = new Float32Array(frames);
  for (let i = 0; i < frames; i++) grit[i] = dice() * 2 - 1;
  const rumble = lowpass(grit, 160, 3);
  const turbo = lowpass(grit, 2400, 1);
  const y = new Float32Array(frames);
  for (let i = 0; i < frames; i++) {
    const t = i / RATE;
    y[i] = x[i] * 0.9 + rumble[i] * 2.2 + turbo[i] * 0.05 * (1 + 0.3 * Math.sin(2 * Math.PI * 2 * t)) + 0.18 * Math.sin(2 * Math.PI * 30 * t) + 0.1 * Math.sin(2 * Math.PI * 15 * t);
  }
  // (The ends of the filtered noise do not meet: the last tenth of a second fades into the first.)
  const lap = Math.floor(0.1 * RATE);
  for (let i = 0; i < lap; i++) {
    const w = i / lap;
    y[i] = y[i] * w + y[frames - lap + i] * (1 - w);
  }
  save('truck_engine', level(y.subarray(0, frames - lap), 0.8));
}

// --- the horn: two tones a third apart, one second.
{
  const frames = Math.floor(1.0 * RATE);
  const y = new Float32Array(frames);
  for (let i = 0; i < frames; i++) {
    const t = i / RATE;
    const env = Math.min(1, t * 40) * Math.min(1, (1.0 - t) * 12);
    let v = 0;
    for (const f of [311, 392]) {
      for (let h = 1; h <= 6; h++) v += Math.sin(2 * Math.PI * f * h * t) / (h * 1.3);
    }
    y[i] = Math.tanh(v * 0.6) * env;
  }
  save('truck_horn', level(lowpass(y, 3200, 1), 0.8));
}

// --- the hydraulics: a strained whine that climbs, with hiss, three seconds.
{
  const frames = Math.floor(3.0 * RATE);
  const y = new Float32Array(frames);
  const hiss = new Float32Array(frames);
  for (let i = 0; i < frames; i++) hiss[i] = dice() * 2 - 1;
  const soft = lowpass(hiss, 900, 2);
  let phase = 0;
  for (let i = 0; i < frames; i++) {
    const t = i / RATE;
    const f = 140 + 90 * (t / 3.0);
    phase += 2 * Math.PI * f / RATE;
    const env = Math.min(1, t * 6) * Math.min(1, (3.0 - t) * 3);
    y[i] = env * (0.5 * Math.sin(phase) + 0.25 * Math.sin(phase * 2.01) + soft[i] * 1.6);
  }
  save('truck_hydraulic', level(y, 0.6));
}
