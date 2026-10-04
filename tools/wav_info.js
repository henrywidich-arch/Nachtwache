// Prints measurements for every WAV in a folder: format, peak, onset, content length, loudness shape.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const wav = require('./wav_lib.js');
const dir = process.argv[2];
const seen = new Map();
for (const name of fs.readdirSync(dir).sort()) {
  if (!name.toLowerCase().endsWith('.wav')) continue;
  const file = path.join(dir, name);
  const hash = crypto.createHash('md5').update(fs.readFileSync(file)).digest('hex').slice(0, 8);
  const dup = seen.has(hash) ? ' DUP of ' + seen.get(hash) : '';
  if (!seen.has(hash)) seen.set(hash, name);
  const s = wav.read(file);
  const m = wav.mono(s);
  const p = wav.peak(m);
  let first = 0, last = m.length - 1;
  while (first < m.length && Math.abs(m[first]) < p * 0.05) first++;
  while (last > 0 && Math.abs(m[last]) < p * 0.02) last--;
  // Loudness in 8 equal slices, in dB relative to full scale.
  const slices = [];
  const step = Math.floor(m.length / 8);
  for (let i = 0; i < 8; i++) slices.push(Math.round(wav.db(wav.rms(m, i * step, (i + 1) * step))));
  // Position of the loudest 10 ms window.
  const win = Math.floor(s.rate * 0.01);
  const env = wav.envelope(m, win);
  let loud = 0;
  for (let i = 1; i < env.length; i++) if (env[i] > env[loud]) loud = i;
  let stereo = 0;
  if (s.channels.length === 2) {
    let diff = 0, sum = 0;
    for (let i = 0; i < s.frames; i++) { const d = s.channels[0][i] - s.channels[1][i]; diff += d * d; sum += m[i] * m[i]; }
    stereo = Math.sqrt(diff / Math.max(sum, 1e-12));
  }
  console.log(
    name.padEnd(46),
    `${s.channels.length}ch ${s.rate}Hz ${s.bits}bit`,
    `${(s.frames / s.rate).toFixed(2)}s`,
    `peak ${wav.db(p).toFixed(1)}dB`,
    `rms ${wav.db(wav.rms(m)).toFixed(1)}dB`,
    `onset ${(first / s.rate * 1000).toFixed(0)}ms`,
    `loudest ${(loud * 10)}ms`,
    `end ${(last / s.rate * 1000).toFixed(0)}ms`,
    `low<250 ${(wav.lowShare(m, s.rate, 250) * 100).toFixed(0)}%`,
    `st ${stereo.toFixed(2)}`,
    `[${slices.join(' ')}]`,
    dup
  );
}
