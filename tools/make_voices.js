// Turns the ElevenLabs recordings into the game's voice files.
//   node tools/make_voices.js <raw folder with the MP3s> <order.json> [--dry]
// The raw files sort by the time they were generated; order.json lists what was generated
// in that order: [{speaker, cue, n, text}]. An order that names the recording of each line
// ("file", as the final orders of 2026-10-10 do) is followed by name instead, and a line
// marked "skip" in it is left out. Each line is trimmed, freed of overlong
// pauses, levelled and written as
// assets/voice/<speaker>/<cue>_<n>.ogg. Everything that comes over the radio (Coleman, and
// Nadja while she is still locked in, the operators who break into the channel) is
// band-limited and compressed like a radio channel; what comes over a loudspeaker (Nadja
// in the facility of the second mission) sounds like one.
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
// (Since 2026-10-10 the squad, Nadja and Coleman speak with voices the user made himself.)
const VOICES = { coleman: 'ColemanNEW', nadja: 'Nadja', viper: 'Viper', scorpion: 'Scorpion', raven: 'Raven', cru: 'Harry', cru2: 'Daniel', cru3: 'Brian', cru4: 'Roger', shop: 'Laura', phantom: 'Phantom', havoc: 'Havoc', ghost: 'Ghost' };
// The three later voices of the C.R.U. are meant to sound hard and without feeling. Each is
// pitched down a little (semitones) and put through a helmet set: a narrow band, pressed
// flat, the roughest of them with a little grit.
const HELMET = 'highpass=f=210,lowpass=f=3900,acompressor=threshold=-24dB:ratio=5:attack=3:release=90:makeup=5';
// level: grit makes a voice denser at the same peak; this many dB bring it back in line.
const HARD = { cru2: { down: 1.5, grit: 0 }, cru3: { down: 3.0, grit: 1, level: -2.5 }, cru4: { down: 1.0, grit: 0 } };
function hard(speaker) {
  const how = HARD[speaker];
  if (!how) return '';
  const ratio = Math.pow(2, -how.down / 12);
  return ',aresample=44100,asetrate=' + Math.round(44100 * ratio) + ',aresample=44100,atempo=' + (1 / ratio).toFixed(5) + ',' + HELMET + (how.grit ? ',volume=5dB,asoftclip=type=tanh' : '');
}
// Nadja speaks in person once she is out of her room, and in the second mission for as
// long as she walks with the squad. Whatever else she says comes over a loudspeaker: the
// lab's in the first mission, the facility's in the second (m2_n_lock, m2_n_cru,
// m2_n_tanks, m2_n_work, m2_n_taunt).
const IN_PERSON = ['nadja_freed', 'nadja_follow', 'nadja_pain', 'nadja_board', 'nadja_channel', 'nadja_static',
  'm2_n_house', 'm2_n_mirror', 'm2_n_open', 'm2_n_wait', 'm2_n_sorry', 'm2_n_home'];
// (The Coleman before this one was slowed down a touch, calm and unhurried even when
// things go wrong. The voice of 2026-10-10 speaks at that pace by itself - slowed down
// as well its lines came out 5 % longer than the old ones - so nothing is stretched now.)
const RADIO = 'highpass=f=330,lowpass=f=3300,acompressor=threshold=-22dB:ratio=5:attack=4:release=90:makeup=5,highpass=f=330,lowpass=f=3300';
const SPEAKER = 'highpass=f=260,lowpass=f=4200,acompressor=threshold=-20dB:ratio=3:attack=5:release=120:makeup=3,aecho=0.8:0.5:38:0.22';
// The three operators break into the Fireteam's channel with sets of their own: a narrower,
// harder band than Coleman's, driven a little too hot. What they shout across the yard
// (every cue that does not begin with op_) stays as it was recorded: their calls as
// companions, and what they say standing before the squad at the station (m2_p_truce,
// m2_h_used, m2_g_radio, m2_g_clear, m2_p_tunnel, m2_p_join). What they report from the
// tunnel later in the second mission comes over the same sets.
const OVER_RADIO = ['m2_g_list', 'm2_h_tunnel', 'm2_p_alive'];
const INTRUDER = 'highpass=f=420,lowpass=f=2900,acompressor=threshold=-24dB:ratio=6:attack=3:release=80:makeup=6,volume=3dB,asoftclip=type=tanh,highpass=f=420,lowpass=f=2900';
const OPERATORS = ['phantom', 'havoc', 'ghost'];
const TRIM = 'silenceremove=start_periods=1:start_threshold=-46dB:start_silence=0.03,areverse,silenceremove=start_periods=1:start_threshold=-46dB:start_silence=0.06,areverse';
// The voices of 2026-10-10 are denser than the ones before them: at the same peak a line
// is that much louder. This many dB bring each back to how loud its lines were in the game
// (measured: the median over the lines both voices have recorded).
// (Ghost is the quiet one of the three operators: his new lines, most of them a word or
// two, sit a little under Phantom's and Havoc's.)
const LEVEL = { viper: -4.0, scorpion: -3.0, raven: -3.0, ghost: -1.5 };
// Nadja's new voice: what she cries out in person in the first mission is 2 dB denser
// than it was; and over the loudspeakers of the facility she is a little louder than
// over the lab's, so that she stands beside Coleman.
function level(line, sound) {
  if (line.speaker === 'nadja') {
    const second = line.cue.startsWith('m2_');
    return sound === 'clean' ? (second ? 0 : -2.0) : (second ? 1.0 : 0);
  }
  return LEVEL[line.speaker] || 0;
}
// A pause inside a line may last this long; a longer one is cut down to it. The voice
// generator now and then leaves seconds of dead air in the middle of a sentence.
const PAUSE = 0.9;
// Nadja's voice leaves a second and more between her sentences. She is afraid and in a
// hurry: her pauses are cut down further. (Not in the second mission: there she is calm,
// and her pauses are meant.)
const PAUSES = { nadja: 0.55 };
function pause_limit(line) {
  return line.cue.startsWith('m2_') ? PAUSE : (PAUSES[line.speaker] || PAUSE);
}

// The filter that takes the middle out of every pause longer than PAUSE, or '' if the
// recording has none. Also returns how many seconds are taken out.
function pauses(file, limit) {
  const out = spawnSync(FFMPEG, ['-hide_banner', '-i', file, '-af', 'silencedetect=noise=-46dB:d=' + limit, '-f', 'null', '-'], { encoding: 'utf8' });
  const text = out.stderr || '';
  const starts = [...text.matchAll(/silence_start: (-?[\d.]+)/g)].map(m => Math.max(0, Number(m[1])));
  const ends = [...text.matchAll(/silence_end: (-?[\d.]+)/g)].map(m => Number(m[1]));
  const cuts = [];
  let cut = 0;
  for (let i = 0; i < ends.length; i++) {
    const from = starts[i] + limit / 2;
    const to = ends[i] - limit / 2;
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

let files = fs.readdirSync(raw).filter(f => f.toLowerCase().endsWith('.mp3')).sort().slice(skip);
let lines = order;
if (order.some(line => line.file)) {
  // A final order: every line names its recording; repeats and tests are marked.
  lines = order.filter(line => !line.skip);
  for (const line of lines) if (!line.file || !fs.existsSync(path.join(raw, line.file))) throw new Error('no recording for ' + line.speaker + '/' + line.cue + '_' + line.n + ': ' + line.file);
  const seen = {};
  for (const line of lines) {
    const key = line.speaker + '/' + line.cue + '_' + line.n;
    if (seen[key]) throw new Error('two recordings for ' + key);
    seen[key] = true;
  }
  files = lines.map(line => line.file);
} else if (files.length !== order.length) throw new Error('files ' + files.length + ' != lines ' + order.length);
const report = [];
let problems = 0;
for (let i = 0; i < files.length; i++) {
  const line = lines[i];
  const file = path.join(raw, files[i]);
  if (!VOICES[line.speaker] || !files[i].includes('_' + VOICES[line.speaker] + '_')) {
    console.log('VOICE MISMATCH', i, files[i], line.speaker, line.cue);
    problems++;
    continue;
  }
  const intruder = OPERATORS.includes(line.speaker) && (line.cue.startsWith('op_') || OVER_RADIO.includes(line.cue));
  const radio = intruder || line.speaker === 'coleman' || (line.speaker === 'nadja' && !IN_PERSON.includes(line.cue));
  const pause = pauses(file, pause_limit(line));
  const chain = pause.filter + TRIM + (line.speaker === 'coleman' ? ',' + RADIO : (intruder ? ',' + INTRUDER : (radio ? ',' + SPEAKER : ''))) + hard(line.speaker);
  const measured = probe(file, chain);
  // Radio lines sit a little under full level; the calls of people nearby use all of it.
  const sound = line.speaker === 'coleman' ? 'radio' : (intruder ? 'set' : (radio ? 'speaker' : 'clean'));
  const gain = (radio ? -2.0 : -1.0) - measured.peak + ((HARD[line.speaker] || {}).level || 0) + level(line, sound);
  const rate = line.text.length / measured.seconds;
  const entry = { file: line.speaker + '/' + line.cue + '_' + line.n, sound, seconds: +measured.seconds.toFixed(2), chars: line.text.length, rate: +rate.toFixed(1), gain: +gain.toFixed(1), mean: measured.mean };
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
fs.writeFileSync(path.join(raw, '..', 'report_' + path.basename(args[1], '.json') + '.json'), JSON.stringify(report, null, 1));
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
