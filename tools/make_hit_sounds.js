// Builds what a shooter hears when his own bullet lands, and the burst of the second
// exploding infected, from the project's own ElevenLabs recordings and a little synthesis:
//   hit_body_1..4   a bullet in flesh: a tight tick, a knock and a short body of wet flesh
//   hit_head_1..3   the same for a head: brighter and harder, with the crack of bone
//   hit_kill_1..3   the hit that kills: fuller and wetter, played on top of the tick
//   boomer_burst_1..3  the second exploder going off: low, wide and wet, with what rains down after it
//   node tools/make_hit_sounds.js <raw folder> <output folder> [--only=hit_body,boomer_burst]
// Nothing here is taken from another game. The files are 48 kHz mono, 16 bit; how loud each
// is played is set in the mix table of scripts/sound.gd.
//
// Why the confirmations look the way they do: a gunshot fills the low end and the first
// hundredths of a second. What is to be heard through it has to live where the shot is
// thin (1 to 5 kHz), has to be over quickly (no tail that piles up at 750 rounds a minute),
// and must not start in the very same instant: every file begins with LEAD seconds of
// silence, so that the tick answers the shot instead of drowning in its first crack.
const fs = require('fs');
const path = require('path');
const wav = require('./wav_lib.js');

const [rawDir, outDir] = process.argv.slice(2);
const only = (process.argv.find(a => a.startsWith('--only=')) || '').slice(7).split(',').filter(Boolean);
const RATE = 48000;
// Silence before a confirmation, in seconds (see above). The burst has none.
const LEAD = 0.022;

const files = fs.readdirSync(rawDir).filter(f => f.toLowerCase().endsWith('.wav')).sort();
// Raw files are named "<prompt start>_#<variant>-<timestamp>.wav".
function raw(prefix, variant) {
  const hit = files.find(f => f.startsWith(prefix) && f.includes(`_#${variant}-`));
  if (!hit) throw new Error(`no raw file for ${prefix} #${variant}`);
  const sound = wav.read(path.join(rawDir, hit));
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

// Always the same noise, so that the files do not change from run to run.
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

function samples(seconds) { return Math.max(1, Math.floor(seconds * RATE)); }
function scaled(x, peak) {
  const top = wav.peak(x);
  return top > 1e-9 ? x.map(v => v * peak / top) : x;
}

// A tick: a few thousandths of a second of noise between `low` and `high` Hz that dies
// away within `tau` seconds. The part of a hit that cuts through a shot.
function tick({ low, high, tau, seed }) {
  const random = noiseSource(seed);
  const n = samples(tau * 9);
  let x = new Float32Array(n);
  for (let i = 0; i < n; i++) x[i] = random();
  x = filter(filter(x, 'high', low), 'low', high);
  const rise = samples(0.00012);
  for (let i = 0; i < n; i++) x[i] *= Math.min(1, i / rise) * Math.exp(-i / RATE / tau);
  return scaled(x, 1);
}

// A knock: a tone that drops from `from` to `to` Hz while it dies away - the pitch of the
// "thwack". It starts at a zero crossing, so it is as sharp as a tone can begin.
function knock({ from, to, glide, tau }) {
  const n = samples(tau * 8);
  const x = new Float32Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    const hz = to + (from - to) * Math.exp(-t / glide);
    phase += 2 * Math.PI * hz / RATE;
    x[i] = Math.sin(phase) * Math.exp(-t / tau);
  }
  return x;
}

// Bone: a few tones that do not fit together, each gone within hundredths of a second.
// Short enough to be a crack, not a bell.
function crack(partials) {
  const n = samples(Math.max(...partials.map(p => p[1])) * 8);
  const x = new Float32Array(n);
  for (const [hz, tau, gain] of partials) {
    for (let i = 0; i < n; i++) {
      const t = i / RATE;
      x[i] += Math.sin(2 * Math.PI * hz * t) * Math.exp(-t / tau) * gain;
    }
  }
  return scaled(x, 1);
}

// A piece of a recording: from `skip` seconds after its first audible sample, played
// faster or slower (`pitch`), filtered, held for `hold` seconds and then dying away within
// `tau` (the recordings ring for a third of a second; a confirmation must not).
function flesh({ from, variant = 1, skip = 0, pitch = 1, high = 0, low = 0, hold = 0.004, tau = 0.03, length = 0.2 }) {
  let x = raw(from, variant);
  const top = wav.peak(x);
  let first = 0;
  while (first < x.length && Math.abs(x[first]) < top * 0.05) first++;
  x = resample(x.subarray(first + samples(skip)), RATE * pitch, RATE);
  x = Float32Array.from(x.subarray(0, Math.min(x.length, samples(length))));
  if (high) x = filter(x, 'high', high);
  if (low) x = filter(x, 'low', low);
  const rise = samples(0.0006);
  const held = samples(hold);
  for (let i = 0; i < x.length; i++) {
    x[i] *= Math.min(1, i / rise) * (i > held ? Math.exp(-(i - held) / RATE / tau) : 1);
  }
  return scaled(x, 1);
}

// Sums the layers ([sound, gain, seconds after the start]), presses the result a little
// (`drive`: denser at the same peak), lets it end in a short fade, puts `lead` seconds of
// silence in front and sets the peak to `peak` dB.
function assemble(name, layers, { length, drive = 0, peak = -1.5, lead = LEAD, fade = 0.012 }) {
  const n = samples(length);
  let sum = new Float32Array(n);
  for (const [sound, gain, offset = 0] of layers) {
    const at = samples(offset) - 1;
    for (let i = 0; i < sound.length && at + i < n; i++) sum[at + i] += sound[i] * gain;
  }
  if (drive) {
    const top = wav.peak(sum);
    sum = sum.map(v => Math.tanh(v / top * drive) / Math.tanh(drive) * top);
  }
  const tail = samples(fade);
  for (let i = 0; i < tail; i++) sum[n - 1 - i] *= i / tail;
  sum = scaled(sum, Math.pow(10, peak / 20));
  const out = new Float32Array(samples(lead) + n);
  out.set(sum, lead > 0 ? samples(lead) : 0);
  const body = lead > 0 ? out : sum;
  wav.write(path.join(outDir, name + '.wav'), { rate: RATE, channels: [body] });
  const loud = Math.min(sum.length, samples(0.05));
  let best = 0;
  for (let from = 0; from + loud <= sum.length; from += samples(0.005)) best = Math.max(best, wav.rms(sum, from, from + loud));
  console.log(name.padEnd(16), `${(body.length / RATE * 1000).toFixed(0)} ms`, `peak ${wav.db(wav.peak(sum)).toFixed(1)} dB`, `loudest 50 ms ${wav.db(best).toFixed(1)} dB`);
}

const BUILD = {
  // A bullet in flesh. The tick and the knock are the answer itself; under them a piece of
  // a wet pop with its boom taken out, and the thud of the old hit sound as weight.
  hit_body: () => {
    const takes = [
      { flesh: { from: 'Wet_fleshy_pop,_slim_', variant: 4, skip: 0.026, high: 450, low: 6500, hold: 0.009, tau: 0.02 }, knock: [1500, 700], seed: 11 },
      { flesh: { from: 'Wet_fleshy_pop,_slim_', variant: 3, pitch: 1.06, high: 450, low: 6500, hold: 0.009, tau: 0.019 }, knock: [1650, 780], seed: 23 },
      { flesh: { from: 'Wet_fleshy_pop,_slim_', variant: 1, pitch: 1.1, high: 480, low: 6500, hold: 0.009, tau: 0.018 }, knock: [1380, 650], seed: 37 },
      { flesh: { from: 'Head_exploding,_wet__', variant: 2, pitch: 0.94, high: 450, low: 5200, hold: 0.009, tau: 0.018 }, knock: [1560, 740], seed: 51 }
    ];
    takes.forEach((take, index) => {
      const thud = flesh({ from: 'Bullet_hitting_flesh_', low: 190, tau: 0.016, hold: 0.008 });
      assemble(`hit_body_${index + 1}`, [
        [tick({ low: 2300, high: 6800, tau: 0.0013, seed: take.seed }), 0.8],
        [knock({ from: take.knock[0], to: take.knock[1], glide: 0.006, tau: 0.0075 }), 0.65],
        [flesh(take.flesh), 1.0, 0.001],
        [thud, 0.3, 0.001]
      ], { length: 0.105, drive: 2.2, peak: -1.5 });
    });
  },
  // A head: the tick is brighter, the knock higher and shorter, bone cracks, and the wet
  // part comes from the takes of a head bursting.
  hit_head: () => {
    const takes = [
      { flesh: { from: 'Head_exploding,_wet__', variant: 4, pitch: 1.12 }, knock: [3100, 1500], bone: [[2380, 0.016, 1], [3540, 0.011, 0.7], [5200, 0.006, 0.45]], seed: 71 },
      { flesh: { from: 'Head_exploding,_wet__', variant: 3, pitch: 1.2 }, knock: [3350, 1650], bone: [[2560, 0.015, 1], [3810, 0.01, 0.7], [5640, 0.006, 0.45]], seed: 83 },
      { flesh: { from: 'Head_exploding,_wet__', variant: 1, pitch: 1.15 }, knock: [2900, 1400], bone: [[2250, 0.017, 1], [3350, 0.011, 0.7], [4950, 0.006, 0.45]], seed: 97 }
    ];
    takes.forEach((take, index) => {
      const thud = flesh({ from: 'Bullet_headshot_impa_', low: 210, tau: 0.026, hold: 0.008 });
      assemble(`hit_head_${index + 1}`, [
        [tick({ low: 3600, high: 9500, tau: 0.001, seed: take.seed }), 0.9],
        [knock({ from: take.knock[0], to: take.knock[1], glide: 0.005, tau: 0.0045 }), 0.7],
        [crack(take.bone), 0.6, 0.0005],
        [flesh(Object.assign({ high: 520, low: 9000, tau: 0.026 }, take.flesh)), 0.75, 0.001],
        [thud, 0.28, 0.001]
      ], { length: 0.14, drive: 2.0, peak: -1.5 });
    });
  },
  // The hit that kills, played on top of the tick: the whole wet pop with its low end, the
  // crunch of something giving way, the thud at full weight, and a few drops after it.
  hit_kill: () => {
    const takes = [
      { pop: { from: 'Wet_fleshy_pop,_slim_', variant: 1, pitch: 0.88 }, crunch: { from: 'Head_exploding,_wet__', variant: 1, pitch: 0.95 }, thud: 'Bullet_hitting_flesh_', drops: 3, knock: [1150, 520], seed: 113 },
      { pop: { from: 'Wet_fleshy_pop,_slim_', variant: 2, pitch: 0.85 }, crunch: { from: 'Chunks_of_meat_and_g_', variant: 2, pitch: 1.2 }, thud: 'Bullet_headshot_impa_', drops: 1, knock: [1260, 560], seed: 127 },
      { pop: { from: 'Wet_fleshy_pop,_slim_', variant: 3, pitch: 0.82 }, crunch: { from: 'Head_exploding,_wet__', variant: 3, pitch: 0.9 }, thud: 'Bullet_hitting_flesh_', drops: 2, knock: [1060, 480], seed: 139 }
    ];
    takes.forEach((take, index) => {
      assemble(`hit_kill_${index + 1}`, [
        [tick({ low: 1800, high: 6000, tau: 0.0016, seed: take.seed }), 0.5],
        [knock({ from: take.knock[0], to: take.knock[1], glide: 0.012, tau: 0.013 }), 0.7],
        [flesh(Object.assign({ high: 110, low: 7000, hold: 0.012, tau: 0.042, length: 0.26 }, take.pop)), 1.0, 0.001],
        [flesh(Object.assign({ high: 260, low: 7500, hold: 0.01, tau: 0.045, length: 0.26 }, take.crunch)), 0.5, 0.004],
        [flesh({ from: take.thud, low: 230, hold: 0.015, tau: 0.045, length: 0.26 }), 0.8, 0.001],
        [flesh({ from: 'Blood_splatter_hitti_', variant: take.drops, high: 1800, hold: 0.06, tau: 0.05, length: 0.2 }), 0.22, 0.05]
      ], { length: 0.25, drive: 1.6, peak: -1.5, fade: 0.03 });
    });
  },
  // The second exploder bursts: not a bang but a sack of something wet going off low and
  // wide. A body torn apart, slowed down; under it the fat burst an octave lower; and what
  // was thrown up comes down again a moment later.
  boomer_burst: () => {
    const takes = [
      { body: 2, pitch: 0.8, rain: [3, 1], seed: 151 },
      { body: 3, pitch: 0.76, rain: [2, 4], seed: 163 },
      { body: 2, pitch: 0.72, rain: [1, 3], seed: 177 }
    ];
    takes.forEach((take, index) => {
      assemble(`boomer_burst_${index + 1}`, [
        [knock({ from: 190, to: 52, glide: 0.05, tau: 0.16 }), 0.6],
        [flesh({ from: 'Body_exploding_into__', variant: take.body, pitch: take.pitch, low: 7500, hold: 0.35, tau: 0.34, length: 1.9 }), 1.0],
        [flesh({ from: 'Head_exploding,_wet__', variant: 1 + index, pitch: 0.8, high: 500, hold: 0.06, tau: 0.1, length: 0.7 }), 0.55, 0.004],
        [flesh({ from: 'Fat_zombie_exploding_', pitch: 0.6, low: 1100, hold: 0.25, tau: 0.3, length: 1.6 }), 0.7, 0.01],
        [flesh({ from: 'Wet_fleshy_pop,_slim_', variant: 2, pitch: 0.55, high: 90, low: 4200, hold: 0.03, tau: 0.09, length: 0.5 }), 0.8],
        [flesh({ from: 'Wet_fleshy_pop,_slim_', variant: 4, skip: 0.02, pitch: 0.85, high: 700, hold: 0.04, tau: 0.08, length: 0.5 }), 0.45, 0.012],
        [flesh({ from: 'Blood_splatter_hitti_', variant: take.rain[0], pitch: 0.8, high: 900, hold: 0.5, tau: 0.25, length: 1.0 }), 0.36, 0.3],
        [flesh({ from: 'Blood_splatter_hitti_', variant: take.rain[1], pitch: 0.7, high: 900, hold: 0.5, tau: 0.25, length: 1.0 }), 0.3, 0.6],
        [flesh({ from: 'Chunks_of_meat_and_g_', variant: 1 + index, pitch: 0.9, hold: 0.2, tau: 0.15, length: 0.6 }), 0.3, 0.45]
      ], { length: 1.9, drive: 1.3, peak: -1.0, lead: 0, fade: 0.35 });
    });
  }
};

fs.mkdirSync(outDir, { recursive: true });
for (const name of Object.keys(BUILD)) {
  if (only.length === 0 || only.includes(name)) BUILD[name]();
}
