// Builds the bright "ding" that answers a hit on an infected - four families of it, each
// with its own character - by synthesis alone: no recording, and nothing taken from
// another game. Every family brings
//   ding_<family>_1..4        a hit: a tick of under two thousandths of a second and a
//                             pitched, bell-like body that drops fast and rings briefly
//   ding_<family>_head_1..3   a head: a fifth higher (the dry one a fourth), brighter, struck twice
//   ding_<family>_kill_1..3   the kill: a lower, rounder bell - the octave below the hit
//                             and its fifth - with a soft thump under it
// The takes of a kind differ a little (the tick, the weight and the length of the upper
// partials) but never in pitch: the game raises the pitch itself, hit by hit, when hits
// follow each other quickly (FieldAudio.LADDER in scripts/sound.gd), and that ladder only
// sounds like one if every take is in tune.
//
//   node tools/make_ding_sounds.js <output folder>            the files of all families (assets/sounds)
//     [--only=glas,messing]                                   only these families
//     [--report]                                              per file: attack, how fast it drops, its strongest partials
//     [--against=<project folder>]                            per kind: how far it stands above every gun of the game,
//                                                             at the levels of the mix table in scripts/sound.gd
//     [--demo=<folder> --project=<project folder>]            WAV files to listen through, with a text file (German)
// The files are 48 kHz mono, 16 bit.
const fs = require('fs');
const path = require('path');
const wav = require('./wav_lib.js');

const args = process.argv.slice(2);
const outDir = args.find(a => !a.startsWith('--'));
const option = name => { const hit = args.find(a => a.startsWith(`--${name}=`)); return hit ? hit.slice(name.length + 3) : ''; };
const only = option('only').split(',').filter(Boolean);
const RATE = 48000;
// Silence before a ding, in seconds: enough to let the first crack of the shot pass.
const LEAD = 0.012;
// What a file's loudest sample is set to (dB below full scale); the mix table does the rest.
const PEAK = -3.0;

// ---------------------------------------------------------------- the families
// pitch: the first partial of a hit, in Hz. Every partial: [ratio to the pitch, level in dB,
// seconds in which it dies away (to 1/e)] - and, if it is to ring on a little after its
// fast drop, [..., share that rings on, its seconds]. `linger`: the same for the first
// partial - [share that rings on, its seconds]. `twin`: the first partial is there
// twice, the second a little off [ratio, level in dB] - the slow beat of a bell.
// tick: the noise of the strike [from Hz, to Hz, seconds, level in dB]. rise: seconds the
// strike takes to be there (a hard or a soft mallet). head: semitones a head lies above a
// hit, the seconds between its two strikes, and what its upper partials gain (dB).
// kill: the seconds its two tones ring, and the level of the thump under them (dB).
const FAMILIES = {
  // Crystal: few partials far apart, a very clean strike. The clearest of the four.
  glas: {
    label: 'Glas', pitch: 2093.0,
    about: 'Kristallglas: sehr sauberer Anschlag, ein klarer heller Ton, wenige weit auseinander liegende Teiltöne. Die klarste der vier.',
    partials: [[1.0, 0, 0.024], [2.32, -7, 0.018, 0.22, 0.055], [4.25, -12, 0.007], [6.63, -18, 0.003]],
    linger: [0.38, 0.08], twin: [1.0035, -10],
    tick: [4000, 11000, 0.00045, -5], rise: 0.00015, drive: 0,
    head: { up: 7, gap: 0.045, bright: 3 },
    kill: { ring: 0.075, thump: -5 }
  },
  // A small brass bell: partials close together, two of them beating, a little warmth
  // from being pressed. The one with the most "bell" in it.
  messing: {
    label: 'Messing', pitch: 1480.0,
    about: 'Kleine Messingglocke: mehrere dicht liegende Teiltöne, zwei davon schweben leicht gegeneinander. Wärmer, am meisten "Glocke".',
    partials: [[1.0, -4, 0.024], [1.506, 0, 0.028], [2.0, -3, 0.022], [2.66, -8, 0.013], [3.34, -12, 0.009], [4.1, -16, 0.005], [5.2, -20, 0.003]],
    linger: [0.25, 0.06], twin: [1.005, -9],
    tick: [2500, 8000, 0.0007, -6], rise: 0.0002, drive: 1.15,
    head: { up: 7, gap: 0.045, bright: 3 },
    kill: { ring: 0.07, thump: -5 }
  },
  // Steel tapped with something hard: many partials, all gone at once. Dry, the shortest.
  tink: {
    label: 'Tink', pitch: 2637.0,
    about: 'Trockenes Metall: viele Teiltöne, alle sofort wieder weg, kaum Nachklang. Die kürzeste, bei Dauerfeuer am unauffälligsten.',
    partials: [[1.0, 0, 0.016], [1.59, -3, 0.013], [2.14, -5, 0.01], [2.65, -8, 0.008], [2.92, -10, 0.006], [3.6, -14, 0.004]],
    linger: [0, 0], twin: [1.0, -99],
    tick: [3000, 10000, 0.0005, -3], rise: 0.00012, drive: 0,
    head: { up: 5, gap: 0.038, bright: 2 },
    kill: { ring: 0.05, thump: -4 }
  },
  // A bar of a glockenspiel under a softer mallet: almost all of it is the first partial.
  // The roundest and mildest.
  spiel: {
    label: 'Glockenspiel', pitch: 1760.0,
    about: 'Stab eines Glockenspiels mit weicherem Schlägel: fast nur der Grundton. Die rundeste und mildeste.',
    partials: [[1.0, 0, 0.03], [2.756, -12, 0.012], [5.404, -22, 0.004]],
    linger: [0.35, 0.085], twin: [1.002, -14],
    tick: [1500, 5000, 0.0009, -10], rise: 0.0006, drive: 0,
    head: { up: 7, gap: 0.05, bright: 4 },
    kill: { ring: 0.09, thump: -6 }
  }
};

// ---------------------------------------------------------------- building blocks
function samples(seconds) { return Math.max(1, Math.round(seconds * RATE)); }
function gain(db) { return Math.pow(10, db / 20); }
function scaled(x, peak) {
  const top = wav.peak(x);
  return top > 1e-9 ? x.map(v => v * peak / top) : x;
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
// Played faster (factor above 1: higher and shorter) or slower - what the game does to a
// sound when it raises its pitch.
function pitched(x, factor) {
  if (factor === 1) return Float32Array.from(x);
  const out = new Float32Array(Math.floor(x.length / factor));
  for (let i = 0; i < out.length; i++) {
    const at = i * factor;
    const a = Math.floor(at);
    const b = Math.min(x.length - 1, a + 1);
    out[i] = x[a] + (x[b] - x[a]) * (at - a);
  }
  return out;
}
function mixInto(target, sound, at, level = 1) {
  const from = Math.round(at * RATE);
  for (let i = 0; i < sound.length && from + i < target.length; i++) target[from + i] += sound[i] * level;
}

// The noise of the strike itself: gone within a thousandth of a second or two.
function tick([low, high, tau, level], seed) {
  const random = noiseSource(seed);
  const n = samples(tau * 9);
  let x = new Float32Array(n);
  for (let i = 0; i < n; i++) x[i] = random();
  x = filter(filter(x, 'high', low), 'low', high);
  const rise = samples(0.00008);
  for (let i = 0; i < n; i++) x[i] *= Math.min(1, i / rise) * Math.exp(-i / RATE / tau);
  return scaled(x, gain(level));
}

// One strike of a bell: the partials of `family` at `pitch`, each dying away at its own
// pace. `vary` shifts the weight and the length of the upper partials a little (a number
// per take); `bright` lifts them (dB); `soft` makes the mallet softer (a longer rise, the
// upper partials weaker) and `ring` lets the first partial ring that long instead.
function strike(family, pitch, { seed = 1, bright = 0, soft = 0, ring = 0, length = 0.45 }) {
  const random = noiseSource(seed * 7919 + 13);
  const n = samples(length);
  const x = new Float32Array(n);
  family.partials.forEach(([ratio, level, tau, longer = 0, longerFor = 0], index) => {
    const upper = index > 0;
    // (The first partial is the pitch: it is never touched.)
    const weight = gain(level + (upper ? bright - soft * 6 * index + random() * 1.5 : 0));
    const lasts = (index === 0 && ring ? ring : tau) * (upper ? 1 + random() * 0.1 : 1);
    const hz = pitch * ratio * (upper ? 1 + random() * 0.002 : 1);
    if (hz > RATE * 0.42) return;
    const phase = upper ? random() * Math.PI : 0;
    const [share, slow] = soft ? [0, 0] : (index === 0 ? family.linger : [longer, longerFor]);
    for (let i = 0; i < n; i++) {
      const t = i / RATE;
      const fade = (1 - share) * Math.exp(-t / lasts) + (share ? share * Math.exp(-t / slow) : 0);
      x[i] += weight * fade * Math.sin(2 * Math.PI * hz * t + phase);
    }
    if (index === 0 && family.twin[1] > -60) {
      const other = gain(level + family.twin[1]);
      for (let i = 0; i < n; i++) {
        const t = i / RATE;
        x[i] += other * Math.exp(-t / (ring || tau * 1.4)) * Math.sin(2 * Math.PI * hz * family.twin[0] * t + 1.1);
      }
    }
  });
  const rise = family.rise + soft * 0.0015;
  for (let i = 0; i < n; i++) x[i] *= 1 - Math.exp(-(i + 0.5) / RATE / rise);
  if (!soft) mixInto(x, tick(family.tick, seed * 31 + 5), 0, wav.peak(x));
  return x;
}

// Presses a sound a little (denser, with a trace of warmth), ends it in a short fade, puts
// the lead in front and sets its loudest sample to PEAK.
function finish(x, { drive = 0, lead = LEAD, fade = 0.02, peak = PEAK }) {
  let y = x;
  if (drive) {
    const top = wav.peak(y);
    y = y.map(v => Math.tanh(v / top * drive) / Math.tanh(drive) * top);
  }
  // No sound below 20 Hz, no step at the end.
  let last = y.length - 1;
  const floor = wav.peak(y) * 0.001;
  while (last > 0 && Math.abs(y[last]) < floor) last--;
  y = Float32Array.from(y.subarray(0, Math.min(y.length, last + samples(fade))));
  const tail = Math.min(y.length, samples(fade));
  for (let i = 0; i < tail; i++) y[y.length - 1 - i] *= i / tail;
  y = scaled(y, gain(peak));
  const out = new Float32Array(samples(lead) + y.length);
  out.set(y, samples(lead));
  return out;
}

// ---------------------------------------------------------------- the three kinds
// (Every take is a little brighter or duller than the one before: a row of them on one
// rung of the ladder is then no row of one sample.)
const TILT = [0, 2, -2, 1];
function hit(family, take) {
  return finish(strike(family, family.pitch, { seed: take, bright: TILT[(take - 1) % TILT.length] }), { drive: family.drive });
}
// A head: the same bell a fifth (or a fourth) higher with brighter partials, struck
// twice - a short one first, the full one right behind it.
function head(family, take) {
  const pitch = family.pitch * Math.pow(2, family.head.up / 12);
  const x = new Float32Array(samples(0.5));
  mixInto(x, strike(family, pitch, { seed: 40 + take, bright: family.head.bright, length: 0.2 }), 0, 0.6);
  mixInto(x, strike(family, pitch, { seed: 50 + take, bright: family.head.bright, length: 0.45 }), family.head.gap, 1.0);
  return finish(x, { drive: family.drive });
}
// The kill: the octave below the hit and its fifth, from a soft mallet, with a thump of
// low sound and a breath of noise under them. It is played together with the hit that
// kills, an octave under it: the two make one chord, and the chord is at rest.
function kill(family, take) {
  const root = family.pitch / 2;
  const x = new Float32Array(samples(0.75));
  mixInto(x, strike(family, root, { seed: 60 + take, soft: 1, ring: family.kill.ring, length: 0.7 }), 0, 1.0);
  mixInto(x, strike(family, root * Math.pow(2, 7 / 12), { seed: 70 + take, soft: 1, ring: family.kill.ring * 0.85, length: 0.7 }), 0.004, 0.7);
  // The thump: a low tone that falls, as short as a blow.
  const n = samples(0.22);
  const thump = new Float32Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    phase += 2 * Math.PI * (62 + 95 * Math.exp(-t / 0.03)) / RATE;
    thump[i] = Math.sin(phase) * Math.exp(-t / 0.05) * (1 - Math.exp(-t / 0.0015));
  }
  const tones = wav.peak(x);
  mixInto(x, thump, 0, tones * gain(family.kill.thump));
  // The breath: soft noise, low, gone in a moment.
  const random = noiseSource(900 + take * 17);
  let puff = new Float32Array(samples(0.12));
  for (let i = 0; i < puff.length; i++) puff[i] = random() * Math.exp(-i / RATE / 0.022) * (1 - Math.exp(-i / RATE / 0.001));
  puff = filter(filter(puff, 'low', 1400), 'high', 180);
  mixInto(x, scaled(puff, tones * gain(-13)), 0);
  return finish(x, { drive: family.drive, fade: 0.04 });
}

const KINDS = [['', hit, 4], ['_head', head, 3], ['_kill', kill, 3]];
function build(name) {
  const family = FAMILIES[name];
  const made = {};
  for (const [suffix, make, takes] of KINDS) {
    made[suffix] = [];
    for (let take = 1; take <= takes; take++) made[suffix].push(make(family, take));
  }
  return made;
}

// ---------------------------------------------------------------- measuring
function fft(re, im) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const angle = -2 * Math.PI / len;
    for (let i = 0; i < n; i += len) {
      for (let k = 0; k < len / 2; k++) {
        const cos = Math.cos(angle * k), sin = Math.sin(angle * k);
        const a = i + k, b = i + k + len / 2;
        const tr = re[b] * cos - im[b] * sin, ti = re[b] * sin + im[b] * cos;
        re[b] = re[a] - tr; im[b] = im[a] - ti; re[a] += tr; im[a] += ti;
      }
    }
  }
}
// The strongest partials of a stretch of sound: [Hz, dB below the strongest].
function strongest(x, from, to, count = 5) {
  const size = 8192;
  const re = new Float64Array(size), im = new Float64Array(size);
  const n = Math.min(to, x.length) - from;
  for (let i = 0; i < n && i < size; i++) re[i] = x[from + i] * (0.5 - 0.5 * Math.cos(2 * Math.PI * i / (n - 1)));
  fft(re, im);
  const level = new Float64Array(size / 2);
  for (let i = 0; i < size / 2; i++) level[i] = Math.hypot(re[i], im[i]);
  const found = [];
  for (let i = 3; i < size / 2 - 1; i++) {
    if (level[i] > level[i - 1] && level[i] >= level[i + 1]) found.push([i * RATE / size, level[i]]);
  }
  found.sort((a, b) => b[1] - a[1]);
  // (A peak next to a stronger one is its skirt, not a partial.)
  const kept = [];
  for (const peak of found) {
    if (kept.every(other => Math.abs(other[0] - peak[0]) > Math.max(60, other[0] * 0.04))) kept.push(peak);
    if (kept.length === count) break;
  }
  const top = kept.length ? kept[0][1] : 1;
  return kept.map(([hz, v]) => [Math.round(hz), Math.round(wav.db(v / top))]);
}
function describe(name, x) {
  const top = wav.peak(x);
  let first = 0;
  while (Math.abs(x[first]) < top * 0.02) first++;
  let loud = first;
  while (Math.abs(x[loud]) < top * 0.9) loud++;
  // The level as time goes on: the loudest sample of every 5 thousandths of a second.
  const at = ms => {
    const a = first + samples(ms / 1000), b = a + samples(0.005);
    let v = 0;
    for (let i = a; i < b && i < x.length; i++) v = Math.max(v, Math.abs(x[i]));
    return Math.round(wav.db(v / top));
  };
  let last = x.length - 1;
  while (last > 0 && Math.abs(x[last]) < top * 0.01) last--;
  const early = strongest(x, first, first + samples(0.03)).map(p => `${p[0]} Hz ${p[1]}`).join(', ');
  const late = strongest(x, first + samples(0.06), first + samples(0.16), 3).map(p => `${p[0]} Hz ${p[1]}`).join(', ');
  console.log(`${name.padEnd(20)} ${(x.length / RATE * 1000).toFixed(0).padStart(4)} ms  peak ${wav.db(top).toFixed(1)} dB  strike ${((loud - first) / RATE * 1000).toFixed(2)} ms` +
    `  after 20/50/100/200 ms ${at(20)}/${at(50)}/${at(100)}/${at(200)} dB  -40 dB after ${((last - first) / RATE * 1000).toFixed(0)} ms`);
  console.log(`${''.padEnd(20)} first 30 ms: ${early}`);
  console.log(`${''.padEnd(20)} 60-160 ms:   ${late}`);
}

// The level of a sound in a third of an octave around `hz`, in steps of 5 ms.
function band(x, hz) {
  let y = filter(filter(x, 'band', hz, 4.3), 'band', hz, 4.3);
  const step = samples(0.005);
  const out = [];
  for (let a = 0; a + step <= y.length; a += step) out.push(wav.rms(y, a, a + step));
  return out;
}
function mixTable(project) {
  const text = fs.readFileSync(path.join(project, 'scripts', 'sound.gd'), 'utf8');
  const table = {};
  for (const match of text.matchAll(/"([a-z0-9_]+)": \[(-?[0-9.]+), [0-9.]+, [0-9]\]/g)) table[match[1]] = parseFloat(match[2]);
  return table;
}
function guns(project) {
  const text = fs.readFileSync(path.join(project, 'scripts', 'player.gd'), 'utf8');
  const found = new Set();
  for (const match of text.matchAll(/"sound": "([a-z0-9_]+)"/g)) found.add(match[1]);
  // (No bullets: the flamethrower and the grenade launcher.)
  found.delete('flamer');
  found.delete('launcher');
  return [...found];
}
function load(file) {
  const sound = wav.read(file);
  const x = wav.mono(sound);
  if (sound.rate === RATE) return x;
  const out = new Float32Array(Math.floor(x.length * RATE / sound.rate));
  for (let i = 0; i < out.length; i++) {
    const at = i * sound.rate / RATE, a = Math.floor(at), b = Math.min(x.length - 1, a + 1);
    out[i] = x[a] + (x[b] - x[a]) * (at - a);
  }
  return out;
}
// How far a ding stands above every gun where it is heard: in the third of an octave
// around its strongest partial (a tone is picked out of noise by what lies right beside
// it), both started together and each at its level in the mix. Per gun: the best 5 ms (at
// the most 40 dB: beyond that the shot is simply over) and how long the ding stays 6 dB and
// more above the shot. Then the gun it stands least above, how loud the ding and a shot
// get together, and how loud ten of them in a row get, a twelfth of a second apart
// and up the ladder (with the answer to a kill on the last).
function against(project, families) {
  const table = mixTable(project);
  const list = guns(project);
  const ladder = ladderOf(project);
  for (const [name, made] of Object.entries(families)) {
    for (const [suffix] of KINDS) {
      const kind = `ding_${name}${suffix}`;
      // (--level=<dB>: the level to assume for a kind that has no line in the mix table yet.)
      if (table[kind] === undefined && option('level')) table[kind] = parseFloat(option('level'));
      if (table[kind] === undefined) { console.log(`${kind}: no line in the mix table yet`); continue; }
      const ding = made[suffix][0].map(v => v * gain(table[kind]));
      let first = 0;
      while (Math.abs(ding[first]) < wav.peak(ding) * 0.02) first++;
      const hz = strongest(ding, first + samples(suffix === '_head' ? 0.035 : 0.002), first + samples(0.09), 1)[0][0];
      const mine = band(ding, hz);
      let line = `${kind.padEnd(18)} @${table[kind]} dB, peak ${wav.db(wav.peak(ding)).toFixed(1)} dB, heard at ${hz} Hz:`;
      let least = 99, leastGun = '', quiet = -99, hot = 0;
      for (const gun of list) {
        const gunFile = path.join(project, 'assets', 'sounds', gun + '.wav');
        if (!fs.existsSync(gunFile) || table[gun] === undefined) continue;
        const shot = load(gunFile).map(v => v * gain(table[gun]));
        const theirs = band(shot, hz);
        let best = -99, above = 0;
        for (let k = 0; k < mine.length; k++) {
          if (wav.db(mine[k]) < -70) continue;
          const margin = Math.min(40, wav.db(mine[k]) - wav.db(k < theirs.length ? theirs[k] : 1e-9));
          best = Math.max(best, margin);
          if (margin >= 6) above += 5;
        }
        let sum = 0;
        for (let i = 0; i < Math.max(ding.length, shot.length); i++) sum = Math.max(sum, Math.abs((i < ding.length ? ding[i] : 0) + (i < shot.length ? shot[i] : 0)));
        // (Some shots of the game are above full scale by themselves, and its limiter holds them:
        // what counts there is what the ding adds. With the others it is how loud the two get.)
        if (wav.db(wav.peak(shot)) >= -3) hot = Math.max(hot, wav.db(sum) - wav.db(wav.peak(shot)));
        else quiet = Math.max(quiet, wav.db(sum));
        line += ` ${gun} +${best.toFixed(0)}/${above}ms`;
        if (best < least) { least = best; leastGun = gun; }
      }
      console.log(line);
      let row = new Float32Array(samples(1.6));
      if (suffix !== '_kill') {
        for (let n = 0; n < 10; n++) mixInto(row, pitched(ding, Math.pow(2, ladder[Math.min(n, ladder.length - 1)] / 12)), n / 12);
      } else {
        const hitLevel = table[`ding_${name}`] === undefined ? table[kind] : table[`ding_${name}`];
        for (let n = 0; n < 10; n++) mixInto(row, pitched(made[''][n % made[''].length], Math.pow(2, ladder[Math.min(n, ladder.length - 1)] / 12)), n / 12, gain(hitLevel + (n === 9 ? -2 : 0)));
        mixInto(row, pitched(ding, Math.pow(2, ladder[Math.min(9, ladder.length - 1)] / 12)), 9 / 12);
      }
      console.log(`${''.padEnd(18)} least above a gun: +${least.toFixed(0)} dB (${leastGun}); with a shot that peaks below -3 dB the two peak at ${quiet.toFixed(1)} dB at the most, to a louder shot it adds ${hot.toFixed(1)} dB at the most; ten in a row peak at ${wav.db(wav.peak(row)).toFixed(1)} dB`);
    }
  }
}

// ---------------------------------------------------------------- to listen through
// What the game makes of a family, as files: the ladder is the game's (it plays the same
// takes faster), so it is played here the same way. `project`: where the game is, for the
// steps of the ladder, the levels of the mix and the shot of a rifle to put under a burst.
function ladderOf(project) {
  const text = fs.readFileSync(path.join(project, 'scripts', 'sound.gd'), 'utf8');
  const match = text.match(/const LADDER := \[([0-9., -]+)\]/);
  return match ? match[1].split(',').map(v => parseFloat(v)) : [0, 1, 2, 3, 4];
}
function demo(folder, project, families) {
  fs.mkdirSync(folder, { recursive: true });
  const ladder = ladderOf(project);
  const table = mixTable(project);
  const source = fs.readFileSync(path.join(project, 'scripts', 'sound.gd'), 'utf8');
  const chosen = (source.match(/const DING := "ding_([a-z]+)"/) || [])[1] || '';
  const pause = (source.match(/const LADDER_PAUSE := ([0-9.]+)/) || [])[1] || '?';
  // (Files 1 to 4 are all set to the same loudness, to compare what they sound like; file
  // 5 is the game's own mix.)
  const write = (name, x, even = true) => wav.write(path.join(folder, name + '.wav'), { rate: RATE, channels: [even ? scaled(x, gain(PEAK)) : x] });
  for (const [name, made] of Object.entries(families)) {
    const label = FAMILIES[name].label;
    const level = suffix => gain(table[`ding_${name}${suffix}`] === undefined ? -8 : table[`ding_${name}${suffix}`]);
    const step = n => Math.pow(2, ladder[Math.min(n, ladder.length - 1)] / 12);
    const take = (suffix, n) => made[suffix][n % made[suffix].length];
    write(`${label}_1_Treffer`, made[''][0]);
    // Ten hits a tenth of a second apart: up the ladder, and on at its top.
    let x = new Float32Array(samples(1.5));
    for (let n = 0; n < 10; n++) mixInto(x, pitched(take('', n), step(n)), 0.05 + n * 0.1, level(''));
    write(`${label}_2_Leiter`, x);
    write(`${label}_3_Kopfschuss`, made['_head'][0]);
    x = new Float32Array(samples(1.0));
    mixInto(x, made[''][0], 0.05, level('') * gain(-2));
    mixInto(x, made['_kill'][0], 0.05, level('_kill'));
    write(`${label}_4_Kill`, x);
    // A burst of the G36 as the game plays it: nine shots, the second misses, the last is
    // a head and kills.
    const shotFile = path.join(project, 'assets', 'sounds', 'g36.wav');
    if (fs.existsSync(shotFile)) {
      const shot = load(shotFile).map(v => v * gain(table.g36 === undefined ? -2 : table.g36));
      x = new Float32Array(samples(1.8));
      let hits = 0;
      for (let n = 0; n < 9; n++) {
        const at = 0.05 + n * 0.083;
        mixInto(x, shot, at);
        if (n === 1) continue;
        if (n === 8) {
          mixInto(x, pitched(take('_head', 0), step(hits)), at, level('_head') * gain(-2));
          mixInto(x, pitched(take('_kill', 0), step(hits)), at, level('_kill'));
        } else {
          mixInto(x, pitched(take('', hits), step(hits)), at, level(''));
        }
        hits++;
      }
      // (As the game's limiter would: nothing above full scale.)
      const top = wav.peak(x);
      if (top > 0.98) x = x.map(v => v * 0.98 / top);
      write(`${label}_5_Feuerstoss_G36`, x, false);
    }
  }
  const lines = [
    'Nachtwache - Treffer-Sounds zum Durchhören',
    '==========================================',
    '',
    'Vier eigene "Ding"-Familien für Treffer auf Infizierte. Alles ist rechnerisch erzeugt',
    '(tools/make_ding_sounds.js im Projekt), nichts stammt aus einem anderen Spiel.',
    '',
    `Im Spiel eingebaut ist: ${chosen && FAMILIES[chosen] ? FAMILIES[chosen].label.toUpperCase() : '?'}`,
    '',
    'Umschalten: in scripts/sound.gd die eine Zeile',
    `    const DING := "ding_${chosen}"`,
    `ändern auf ${Object.keys(FAMILIES).filter(name => name !== chosen).map(name => `"ding_${name}"`).join(', ')}.`,
    'Mehr ist nicht nötig, alle vier Familien liegen schon im Spiel.',
    '',
    'Wichtig: Solange in deinem Spielordner der Ordner "CombatArms_Zombie_Treffersounds" liegt,',
    'spielt das Spiel auf deinem PC weiter deine eigenen Dateien. Um unsere im Spiel zu hören,',
    'den Ordner kurz umbenennen.',
    '',
    'Die Familien',
    '------------'
  ];
  for (const name of Object.keys(families)) lines.push(`${FAMILIES[name].label}: ${FAMILIES[name].about}`, '');
  lines.push(
    'Die Dateien je Familie',
    '----------------------',
    '_1_Treffer         ein einzelner Treffer',
    '_2_Leiter          zehn Treffer kurz hintereinander, wie bei Dauerfeuer: jeder schnelle',
    `                   Folgetreffer klingt höher (${ladder.join(', ')} Halbtöne über dem ersten),`,
    `                   oben bleibt es stehen. Nach ${pause} s Pause oder nach einem Kill`,
    '                   beginnt es wieder unten.',
    '_3_Kopfschuss      Kopftreffer: höher, heller, doppelt angeschlagen',
    '_4_Kill            der Treffer, der tötet: dazu eine tiefere, rundere Glocke (die Oktave',
    '                   darunter und ihre Quinte) mit einem weichen Schlag darunter',
    '_5_Feuerstoss_G36  so sitzt es im Spiel: neun Schüsse mit dem G36, der zweite geht',
    '                   daneben, der letzte ist ein Kopfschuss und tötet',
    '',
    'Die Dateien 1 bis 4 sind alle gleich laut gemacht, damit man den Klang vergleichen kann.',
    'Datei 5 hat die Lautstärken wie im Spiel.',
    '',
    'Soldaten (C.R.U., Operatoren) behalten den fleischigen Treffer-Ton.',
    '',
    'Zum Nachstellen (scripts/sound.gd): die Lautstärken stehen in MIX unter "ding_...",',
    'die Leiter in LADDER (Halbtöne) und LADDER_PAUSE (Sekunden).',
    ''
  );
  fs.writeFileSync(path.join(folder, 'LIESMICH.txt'), '\ufeff' + lines.join('\r\n'), 'utf8');
  console.log(`files to listen through written to ${folder}`);
}

// ---------------------------------------------------------------- run
const names = Object.keys(FAMILIES).filter(name => only.length === 0 || only.includes(name));
const families = {};
for (const name of names) families[name] = build(name);
if (outDir) {
  fs.mkdirSync(outDir, { recursive: true });
  for (const [name, made] of Object.entries(families)) {
    for (const [suffix] of KINDS) {
      made[suffix].forEach((x, index) => wav.write(path.join(outDir, `ding_${name}${suffix}_${index + 1}.wav`), { rate: RATE, channels: [x] }));
    }
  }
  console.log(`${names.length} families written to ${outDir}`);
}
if (args.includes('--report')) {
  for (const [name, made] of Object.entries(families)) {
    for (const [suffix] of KINDS) made[suffix].forEach((x, index) => describe(`ding_${name}${suffix}_${index + 1}`, x));
  }
}
if (option('against')) against(option('against'), families);
if (option('demo')) demo(option('demo'), option('project') || option('against') || '.', families);
