// Turns the ElevenLabs recordings into the game's voice files.
//   node tools/make_voices.js <raw folder with the MP3s> <order.json> [--dry]
// The raw files sort by the time they were generated; order.json lists what was generated
// in that order: [{speaker, cue, n, text}]. Each line is trimmed, freed of overlong
// pauses, levelled and written as
// assets/voice/<speaker>/<cue>_<n>.ogg. Everything that comes over the radio (Coleman, and
// Nadja while she is still locked in) is band-limited and compressed like a radio channel.
const fs = require('fs');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');

const FFMPEG = process.env.FFMPEG || 'C:/Users/bitef/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-9.0.2-full_build/bin/ffmpeg.exe';
const args = process.argv.slice(2);
const raw = args[0];
const order = JSON.parse(fs.readFileSync(args[1], 'utf8'));
const dry = args.includes('--dry');
const skip = Number((args.find(a => a.startsWith('--skip=')) || '--skip=0').slice(7));
const project = path.join(__dirname, '..');
// Which ElevenLabs voice has to stand behind each speaker; a mismatch means the order is off.
const VOICES = { coleman: 'Colonel Coleman', nadja: 'Nadja', viper: 'Matilda', scorpion: 'Callum', raven: 'Lily', cru: 'Harry', shop: 'Laura' };
// Nadja speaks in person once she is out of her room.
const IN_PERSON = ['nadja_freed', 'nadja_follow', 'nadja_pain', 'nadja_board'];
// Coleman is slowed down a touch: calm and unhurried even when things go wrong.
const RADIO = 'atempo=0.94,highpass=f=330,lowpass=f=3300,acompressor=threshold=-22dB:ratio=5:attack=4:release=90:makeup=5,highpass=f=330,lowpass=f=3300';
const SPEAKER = 'highpass=f=260,lowpass=f=4200,acompressor=threshold=-20dB:ratio=3:attack=5:release=120:makeup=3,aecho=0.8:0.5:38:0.22';
const TRIM = 'silenceremove=start_periods=1:start_threshold=-46dB:start_silence=0.03,areverse,silenceremove=start_periods=1:start_threshold=-46dB:start_silence=0.06,areverse';
// A pause inside a line may last this long; a longer one is cut down to it. The voice
// generator now and then leaves seconds of dead air in the middle of a sentence.
const PAUSE = 0.9;

// The filter that takes the middle out of every pause longer than PAUSE, or '' if the
// recording has none. Also returns how many seconds are taken out.
function pauses(file) {
  const out = spawnSync(FFMPEG, ['-hide_banner', '-i', file, '-af', 'silencedetect=noise=-46dB:d=' + PAUSE, '-f', 'null', '-'], { encoding: 'utf8' });
  const text = out.stderr || '';
  const starts = [...text.matchAll(/silence_start: (-?[\d.]+)/g)].map(m => Math.max(0, Number(m[1])));
  const ends = [...text.matchAll(/silence_end: (-?[\d.]+)/g)].map(m => Number(m[1]));
  const cuts = [];
  let cut = 0;
  for (let i = 0; i < ends.length; i++) {
    const from = starts[i] + PAUSE / 2;
    const to = ends[i] - PAUSE / 2;
    if (to - from > 0.05) {
      cuts.push('between(t,' + from.toFixed(3) + ',' + to.toFixed(3) + ')');
      cut += to - from;
    }
  }
  return { filter: cuts.length ? "aselect='not(" + cuts.join('+') + ")',asetpts=N/SR/TB," : '', cut };
}

function probe(file, filter) {
  const out = spawnSync(FFMPEG, ['-hide_banner', '-i', file, '-af', filter + ',volumedetect', '-f', 'null', '-'], { encoding: 'utf8' });
  const text = out.stderr || '';
  const peak = Number((text.match(/max_volume: (-?[\d.]+) dB/) || [0, 'NaN'])[1]);
  const mean = Number((text.match(/mean_volume: (-?[\d.]+) dB/) || [0, 'NaN'])[1]);
  const times = [...text.matchAll(/time=(\d+):(\d+):([\d.]+)/g)];
  const last = times.length ? times[times.length - 1] : null;
  const seconds = last ? Number(last[1]) * 3600 + Number(last[2]) * 60 + Number(last[3]) : NaN;
  return { peak, mean, seconds };
}

const files = fs.readdirSync(raw).filter(f => f.toLowerCase().endsWith('.mp3')).sort().slice(skip);
if (files.length !== order.length) throw new Error('files ' + files.length + ' != lines ' + order.length);
const report = [];
let problems = 0;
for (let i = 0; i < files.length; i++) {
  const line = order[i];
  const file = path.join(raw, files[i]);
  if (!files[i].includes('_' + VOICES[line.speaker])) {
    console.log('VOICE MISMATCH', i, files[i], line.speaker, line.cue);
    problems++;
    continue;
  }
  const radio = line.speaker === 'coleman' || (line.speaker === 'nadja' && !IN_PERSON.includes(line.cue));
  const pause = pauses(file);
  const chain = pause.filter + TRIM + (line.speaker === 'coleman' ? ',' + RADIO : (radio ? ',' + SPEAKER : ''));
  const measured = probe(file, chain);
  // Radio lines sit a little under full level; the calls of people nearby use all of it.
  const gain = (radio ? -2.0 : -1.0) - measured.peak;
  const rate = line.text.length / measured.seconds;
  const entry = { file: line.speaker + '/' + line.cue + '_' + line.n, seconds: +measured.seconds.toFixed(2), chars: line.text.length, rate: +rate.toFixed(1), gain: +gain.toFixed(1), mean: measured.mean };
  if (pause.cut > 0) entry.pause_cut = +pause.cut.toFixed(2);
  // A recording far slower than speech is carries more than the line.
  const longest = 1.2 + line.text.length / 9.0;
  if (!(measured.seconds > 0.25) || measured.seconds > longest) {
    entry.suspect = true;
    problems++;
  }
  report.push(entry);
  if (dry) continue;
  const target = path.join(project, 'assets', 'voice', line.speaker);
  fs.mkdirSync(target, { recursive: true });
  execFileSync(FFMPEG, ['-hide_banner', '-loglevel', 'error', '-y', '-i', file, '-af', chain + ',volume=' + gain.toFixed(2) + 'dB', '-ac', '1', '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '5', path.join(target, line.cue + '_' + line.n + '.ogg')]);
}
fs.writeFileSync(path.join(raw, '..', 'report.json'), JSON.stringify(report, null, 1));
const by = {};
for (const entry of report) {
  const speaker = entry.file.split('/')[0];
  by[speaker] = by[speaker] || { lines: 0, seconds: 0, rates: [] };
  by[speaker].lines++;
  by[speaker].seconds += entry.seconds;
  by[speaker].rates.push(entry.rate);
}
for (const speaker in by) {
  const rates = by[speaker].rates.sort((a, b) => a - b);
  console.log(speaker.padEnd(9), String(by[speaker].lines).padStart(3), 'lines', by[speaker].seconds.toFixed(1).padStart(6), 's   chars/s', rates[0], '..', rates[Math.floor(rates.length / 2)], '..', rates[rates.length - 1]);
}
for (const entry of report.filter(e => e.pause_cut)) console.log('PAUSE CUT', entry.file, entry.pause_cut + ' s taken out');
for (const entry of report.filter(e => e.suspect)) console.log('SUSPECT', JSON.stringify(entry));
console.log(problems === 0 ? 'OK ' + report.length + ' lines' : problems + ' PROBLEMS');
