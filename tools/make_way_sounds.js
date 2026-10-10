// Builds the noises of the ways in of mission two (scripts/hive_entries.gd) by synthesis:
//   hive_way_rattle_1..2   a loose grille or sheet rattles in its frame - the warning
//   hive_way_bang_1..2     a blow on sheet metal, and the grille gives - somebody comes through
//   hive_way_knock         fists on wood or glass - the warning at a window and at the hatch
//   hive_way_glass         a window bursts
//   hive_way_scrabble      claws and loose stones - somebody climbs up out of the track
//   node tools/make_way_sounds.js <output folder>
// Nothing is recorded and nothing is taken from anywhere: struck metal is a handful of
// partials that do not fit each other and die away at different speeds, a knock is a low
// thud, glass is a great many very short high tones. 44.1 kHz mono, 16 bit; how loud
// each is played is set where it is played.
const path = require('path');
const wav = require('./wav_lib.js');

const outDir = process.argv[2];
if (!outDir) { console.error('usage: node tools/make_way_sounds.js <output folder>'); process.exit(1); }
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
  if (kind === 'low') { b0 = (1 - cos) / 2; b1 = 1 - cos; b2 = (1 - cos) / 2; }
  else if (kind === 'high') { b0 = (1 + cos) / 2; b1 = -(1 + cos); b2 = (1 + cos) / 2; }
  else { b0 = alpha; b1 = 0; b2 = -alpha; }
  const a0 = 1 + alpha, a1 = -2 * cos, a2 = 1 - alpha;
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < x.length; i++) {
    const y = (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
    x2 = x1; x1 = x[i]; y2 = y1; y1 = y;
    x[i] = y;
  }
  return x;
}

// Noise of `seconds`, shaped by a filter, dying away with `decay` (1/s).
function grain(rand, seconds, kind, cutoff, q, decay) {
  const g = buffer(seconds);
  for (let i = 0; i < g.length; i++) g[i] = rand() * 2 - 1;
  filter(g, kind, cutoff, q);
  for (let i = 0; i < g.length; i++) g[i] *= Math.exp(-decay * i / RATE) * Math.min(1, i / (0.0006 * RATE));
  return g;
}

// Something struck: partials [frequency, level, decay (1/s)] ringing from `at` seconds on.
// `bend` lets them sink a little as they die (sheet metal does).
function strike(out, at, partials, level, bend = 0) {
  const start = Math.round(at * RATE);
  for (const [freq, amp, decay] of partials) {
    let phase = 0;
    const length = Math.min(out.length - start, Math.round(7 / decay * RATE));
    for (let i = 0; i < length; i++) {
      const t = i / RATE;
      phase += 2 * Math.PI * freq * (1 - bend * (1 - Math.exp(-t * 9))) / RATE;
      out[start + i] += Math.sin(phase) * amp * level * Math.exp(-decay * t) * Math.min(1, i / (0.0004 * RATE));
    }
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

// The partials of a grille of thin steel: they do not fit each other, which is what makes
// it metal. Every variant has its own.
function grilleTones(rand, low) {
  const tones = [];
  let f = low;
  for (let k = 0; k < 7; k++) {
    tones.push([f, 1 / (1 + k * 0.45), 26 + k * 9 + rand() * 12]);
    f *= 1.37 + rand() * 0.42;
  }
  return tones;
}

// --- the grille rattles: a dozen or so knocks of it against its frame, uneven, swelling
function rattle(seed, low) {
  const rand = dice(seed);
  const out = buffer(0.78);
  const tones = grilleTones(rand, low);
  let t = 0.004;
  while (t < 0.66) {
    const swell = 0.35 + 0.65 * Math.sin(Math.PI * Math.min(1, t / 0.62));
    const hit = (0.5 + rand() * 0.5) * swell;
    // (Each knock rings a little differently: where the grille touches changes.)
    const some = tones.map(([f, a, d]) => [f * (0.985 + rand() * 0.03), a * (0.5 + rand() * 0.7), d * 1.6]);
    strike(out, t, some, hit * 0.5);
    add(out, t, grain(rand, 0.02, 'band', 2600 + rand() * 2600, 1.2, 190), hit * 0.9);
    t += 0.026 + rand() * 0.05 + (rand() < 0.2 ? 0.05 : 0);
  }
  // The frame it hangs in hums along, low.
  strike(out, 0.0, [[low * 0.31, 0.5, 6], [low * 0.47, 0.3, 8]], 0.22);
  return finish(filter(out, 'high', 140));
}

// --- a blow on sheet metal: the thump of the body behind it, the sheet ringing down, and
// what was loose clattering after it
function bang(seed, low) {
  const rand = dice(seed);
  const out = buffer(0.72);
  strike(out, 0.0, [[low * 0.36, 1.0, 20]], 0.9, 0.35);
  const sheet = [];
  let f = low;
  for (let k = 0; k < 8; k++) {
    sheet.push([f, 1 / (1 + k * 0.55), 7 + k * 3.5 + rand() * 4]);
    f *= 1.31 + rand() * 0.36;
  }
  strike(out, 0.0, sheet, 0.5, 0.05);
  add(out, 0.0, grain(rand, 0.05, 'low', 3200, 0.7, 70), 1.1);
  const loose = grilleTones(rand, low * 3.4);
  for (const at of [0.085 + rand() * 0.03, 0.17 + rand() * 0.04, 0.27 + rand() * 0.05, 0.4 + rand() * 0.05]) {
    const hit = 0.5 * Math.exp(-at * 3.2) * (0.6 + rand() * 0.6);
    strike(out, at, loose.map(([p, a, d]) => [p * (0.98 + rand() * 0.04), a, d * 1.5]), hit);
    add(out, at, grain(rand, 0.016, 'band', 3000 + rand() * 2000, 1.3, 220), hit * 1.2);
  }
  return finish(filter(out, 'high', 45));
}

// --- fists on wood, or on a pane that still holds: dull, quick, three and one more
function knock(seed) {
  const rand = dice(seed);
  const out = buffer(0.74);
  const times = [0.0, 0.17, 0.33, 0.52];
  times.forEach((at, k) => {
    const hit = [1.0, 0.8, 0.95, 0.6][k];
    strike(out, at, [[96 + rand() * 14, 1.0, 34], [171 + rand() * 20, 0.6, 46], [262 + rand() * 30, 0.35, 60]], hit * 0.8, 0.2);
    add(out, at, grain(rand, 0.03, 'low', 950, 0.8, 120), hit * 1.2);
    // What sits loose in its frame answers.
    strike(out, at + 0.012, [[2350 + rand() * 300, 0.5, 60], [3420 + rand() * 400, 0.3, 80]], hit * 0.05);
  });
  return finish(filter(out, 'high', 55));
}

// --- a pane bursts: the crack, then a great many splinters, each a short high tone,
// thinning out as they come down
function glass(seed) {
  const rand = dice(seed);
  const out = buffer(1.05);
  add(out, 0.0, grain(rand, 0.06, 'high', 1700, 0.7, 60), 1.0);
  strike(out, 0.0, [[150, 1.0, 40], [233, 0.5, 50]], 0.5, 0.2);
  for (let k = 0; k < 90; k++) {
    // (Most of them at once, the last ones as they reach the floor.)
    const at = 0.004 + Math.pow(rand(), 2.2) * 0.8;
    const freq = 2300 + Math.pow(rand(), 1.4) * 7200;
    strike(out, at, [[freq, 1.0, 34 + rand() * 80], [freq * (1.5 + rand() * 0.2), 0.4, 70 + rand() * 60]], (0.05 + rand() * 0.13) * Math.exp(-at * 2.0));
  }
  for (let k = 0; k < 16; k++) {
    const at = 0.02 + rand() * 0.6;
    add(out, at, grain(rand, 0.012, 'band', 5000 + rand() * 4000, 2.0, 300), 0.3 * Math.exp(-at * 2.5));
  }
  return finish(filter(out, 'high', 110));
}

// --- up out of the track: loose stones give under hands and feet, claws drag over
// concrete, something touches the rail
function scrabble(seed) {
  const rand = dice(seed);
  const out = buffer(0.8);
  let t = 0.0;
  while (t < 0.68) {
    add(out, t, grain(rand, 0.018 + rand() * 0.03, 'band', 700 + rand() * 1900, 0.9, 90 + rand() * 80), 0.35 + rand() * 0.55);
    t += 0.022 + rand() * 0.06;
  }
  for (const at of [0.06, 0.29, 0.47]) {
    // A scrape: noise through a narrow gap that opens upwards.
    const length = 0.09 + rand() * 0.05;
    const scrape = buffer(length);
    for (let i = 0; i < scrape.length; i++) scrape[i] = rand() * 2 - 1;
    filter(scrape, 'band', 1500 + rand() * 900, 2.5);
    filter(scrape, 'high', 900);
    for (let i = 0; i < scrape.length; i++) scrape[i] *= Math.sin(Math.PI * i / scrape.length) * 0.9;
    add(out, at + rand() * 0.03, scrape, 0.8);
  }
  strike(out, 0.21, [[1830, 1.0, 24], [2710, 0.5, 30], [4120, 0.3, 44]], 0.12);
  strike(out, 0.55, [[1790, 1.0, 26], [2650, 0.5, 34]], 0.08);
  return finish(filter(out, 'high', 160), -2.5);
}

save('hive_way_rattle_1', rattle(4101, 640));
save('hive_way_rattle_2', rattle(4102, 790));
save('hive_way_bang_1', bang(4201, 205));
save('hive_way_bang_2', bang(4202, 176));
save('hive_way_knock', knock(4301));
save('hive_way_glass', glass(4401));
save('hive_way_scrabble', scrabble(4501));
