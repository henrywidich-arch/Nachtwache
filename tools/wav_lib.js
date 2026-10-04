// Minimal PCM WAV reader/writer plus a few measurements for preparing game sounds.
const fs = require('fs');

function read(file) {
  const data = fs.readFileSync(file);
  if (data.toString('ascii', 0, 4) !== 'RIFF' || data.toString('ascii', 8, 12) !== 'WAVE') throw new Error('not a wav: ' + file);
  let pos = 12, fmt = null, pcm = null;
  while (pos + 8 <= data.length) {
    const id = data.toString('ascii', pos, pos + 4);
    const size = data.readUInt32LE(pos + 4);
    if (id === 'fmt ') {
      fmt = {
        format: data.readUInt16LE(pos + 8),
        channels: data.readUInt16LE(pos + 10),
        rate: data.readUInt32LE(pos + 12),
        bits: data.readUInt16LE(pos + 22)
      };
    } else if (id === 'data') {
      pcm = data.subarray(pos + 8, Math.min(data.length, pos + 8 + size));
    }
    pos += 8 + size + (size & 1);
  }
  if (!fmt || !pcm) throw new Error('missing chunks: ' + file);
  const bytes = fmt.bits / 8;
  const frames = Math.floor(pcm.length / (bytes * fmt.channels));
  const channels = [];
  for (let c = 0; c < fmt.channels; c++) channels.push(new Float32Array(frames));
  for (let i = 0; i < frames; i++) {
    for (let c = 0; c < fmt.channels; c++) {
      const o = (i * fmt.channels + c) * bytes;
      let v;
      if (fmt.format === 3) v = bytes === 4 ? pcm.readFloatLE(o) : pcm.readDoubleLE(o);
      else if (bytes === 2) v = pcm.readInt16LE(o) / 32768;
      else if (bytes === 3) v = pcm.readIntLE(o, 3) / 8388608;
      else if (bytes === 4) v = pcm.readInt32LE(o) / 2147483648;
      else v = (pcm.readUInt8(o) - 128) / 128;
      channels[c][i] = v;
    }
  }
  return { rate: fmt.rate, bits: fmt.bits, format: fmt.format, channels, frames };
}

function write(file, sound) {
  const count = sound.channels.length;
  const frames = sound.channels[0].length;
  const out = Buffer.alloc(44 + frames * count * 2);
  out.write('RIFF', 0, 'ascii');
  out.writeUInt32LE(36 + frames * count * 2, 4);
  out.write('WAVE', 8, 'ascii');
  out.write('fmt ', 12, 'ascii');
  out.writeUInt32LE(16, 16);
  out.writeUInt16LE(1, 20);
  out.writeUInt16LE(count, 22);
  out.writeUInt32LE(sound.rate, 24);
  out.writeUInt32LE(sound.rate * count * 2, 28);
  out.writeUInt16LE(count * 2, 32);
  out.writeUInt16LE(16, 34);
  out.write('data', 36, 'ascii');
  out.writeUInt32LE(frames * count * 2, 40);
  for (let i = 0; i < frames; i++) {
    for (let c = 0; c < count; c++) {
      const v = Math.max(-1, Math.min(1, sound.channels[c][i]));
      out.writeInt16LE(Math.round(v * 32767), 44 + (i * count + c) * 2);
    }
  }
  fs.writeFileSync(file, out);
}

function mono(sound) {
  if (sound.channels.length === 1) return sound.channels[0];
  const mix = new Float32Array(sound.frames);
  for (let i = 0; i < sound.frames; i++) {
    let sum = 0;
    for (const ch of sound.channels) sum += ch[i];
    mix[i] = sum / sound.channels.length;
  }
  return mix;
}

function peak(samples) {
  let p = 0;
  for (let i = 0; i < samples.length; i++) p = Math.max(p, Math.abs(samples[i]));
  return p;
}

function rms(samples, from = 0, to = samples.length) {
  let sum = 0;
  for (let i = from; i < to; i++) sum += samples[i] * samples[i];
  return Math.sqrt(sum / Math.max(1, to - from));
}

// Short-window loudness envelope (window in frames).
function envelope(samples, window) {
  const out = [];
  for (let i = 0; i + window <= samples.length; i += window) out.push(rms(samples, i, i + window));
  return out;
}

function db(v) { return 20 * Math.log10(Math.max(v, 1e-9)); }

// Share of the signal energy below a cutoff, via a one-pole low-pass (rough "how bassy is it").
function lowShare(samples, rate, cutoff) {
  const a = Math.exp(-2 * Math.PI * cutoff / rate);
  let state = 0, low = 0, all = 0;
  for (let i = 0; i < samples.length; i++) {
    state = (1 - a) * samples[i] + a * state;
    low += state * state;
    all += samples[i] * samples[i];
  }
  return all > 0 ? low / all : 0;
}

module.exports = { read, write, mono, peak, rms, envelope, db, lowShare };
