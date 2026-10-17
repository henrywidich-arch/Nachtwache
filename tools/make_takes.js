// Builds scripts/radio_takes.gd (the takes of later recordings, see Radio) from tools/voice_takes/*.json
// and writes the order lists for the recording of them.
//   node tools/make_takes.js [--orders=<dir>] [--all]
// tools/voice_takes/<name>.json: {"bark": {cue: {speaker: [text, ...]}}, "line": {cue: {speaker, takes: [text, ...]}}}
// plus tools/voice_takes/paired.json: {"paired": [cue, ...]} (cues of a short talk of several voices).
// The number of a take is the number of variants written in scripts/radio.gd (BASE_*) plus its place in
// the takes of that speaker and cue (files in name order), so a recording <speaker>/<cue>_<n>.ogg keeps
// its number; never insert takes before existing ones, only append.
// --orders=<dir>: one order_<speaker>.json per speaker there: [{speaker, cue, n, text, tone}] of the takes that
// have no recording yet (--all: every take), and order_all.json. The tone is only a hint for the recording
// (how lively the voice is asked to be): natural, lively, calm or urgent, varied from take to take.
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const project = path.join(__dirname, '..');
const args = process.argv.slice(2);
const ordersDir = (args.find((a) => a.startsWith('--orders=')) || '').slice(9);
const all = args.includes('--all');
const GODOT = process.env.GODOT || 'D:/Games/AI Games/Godot_v4.7.2-stable_win64.exe';
const takesDir = path.join(project, 'tools', 'voice_takes');

// What radio.gd has written first.
const dumpFile = path.join(process.env.TEMP || '/tmp', 'nachtwache_base_dump.json');
const run = spawnSync(GODOT, ['--headless', '--path', project, '-s', 'res://tools/voice_check.gd', '--', '--dump=' + dumpFile.replace(/\\/g, '/')], { encoding: 'utf8', timeout: 180000 });
if (!fs.existsSync(dumpFile)) throw new Error('no dump: ' + run.stdout + run.stderr);
const base = JSON.parse(fs.readFileSync(dumpFile, 'utf8'));
const baseBark = (cue, speaker) => ((base.barks[cue] || {})[speaker] || []).length;
const baseLine = (cue) => (base.lines[cue] ? base.lines[cue].takes.length : 0);

const bark = {}; // cue -> speaker -> [texts]
const line = {}; // cue -> {speaker, takes}
let paired = [];
for (const file of fs.readdirSync(takesDir).filter((f) => f.endsWith('.json')).sort()) {
  const data = JSON.parse(fs.readFileSync(path.join(takesDir, file), 'utf8'));
  if (data.paired) paired = paired.concat(data.paired);
  for (const cue in data.bark || {}) for (const speaker in data.bark[cue]) {
    ((bark[cue] = bark[cue] || {})[speaker] = bark[cue][speaker] || []).push(...data.bark[cue][speaker]);
  }
  for (const cue in data.line || {}) {
    const entry = data.line[cue];
    if (line[cue] && line[cue].speaker !== entry.speaker) throw new Error('two speakers for ' + cue);
    line[cue] = line[cue] || { speaker: entry.speaker, takes: [] };
    line[cue].takes.push(...entry.takes);
  }
}
paired = [...new Set(paired)].sort();
for (const cue of paired) if (!bark[cue] && !base.barks[cue]) throw new Error('paired cue without lines: ' + cue);

const q = (s) => JSON.stringify(s);
let gd = 'class_name RadioTakes\nextends RefCounted\n';
gd += '## The takes that came after the first recordings of the voices (see Radio): more variants of\n';
gd += '## cues that exist, and cues of their own. They are put after the variants written in\n';
gd += '## radio.gd, so every recording keeps its number (<cue>_<n>.ogg).\n';
gd += '## Written by tools/make_takes.js from tools/voice_takes/*.json - do not edit by hand.\n\n';
gd += '## cue -> [speaker, [variants]]\nconst LINES := {\n';
gd += Object.keys(line).sort().map((cue) => '\t' + q(cue) + ': [' + q(line[cue].speaker) + ', [\n' + line[cue].takes.map((t) => '\t\t' + q(t)).join(',\n') + '\n\t]]').join(',\n');
gd += '\n}\n## cue -> {speaker -> [variants]}\nconst BARKS := {\n';
gd += Object.keys(bark).sort().map((cue) => '\t' + q(cue) + ': {\n' + Object.keys(bark[cue]).sort().map((speaker) => '\t\t' + q(speaker) + ': [\n' + bark[cue][speaker].map((t) => '\t\t\t' + q(t)).join(',\n') + '\n\t\t]').join(',\n') + '\n\t}').join(',\n');
gd += '\n}\n## Cues of a short talk of several voices, in which variant n of every speaker belongs to\n';
gd += '## variant n of the others: one is picked for all of them (Radio.bark).\n';
gd += 'const PAIRED: Array[String] = [' + paired.map(q).join(', ') + ']\n';
fs.writeFileSync(path.join(project, 'scripts', 'radio_takes.gd'), gd);

// The orders.
const TONES = ['natural', 'lively', 'calm', 'urgent'];
const entries = [];
function add(speaker, cue, start, texts) {
  texts.forEach((text, k) => {
    let tone = TONES[(k + cue.length + speaker.length) % TONES.length];
    const bangs = (text.match(/!/g) || []).length;
    if (tone === 'calm' && bangs > 0) tone = 'lively';
    if (tone === 'urgent' && bangs === 0) tone = 'natural';
    if (tone === 'natural' && bangs > 1) tone = 'urgent';
    entries.push({ speaker, cue, n: start + k + 1, text, tone });
  });
}
for (const cue in bark) for (const speaker in bark[cue]) add(speaker, cue, baseBark(cue, speaker), bark[cue][speaker]);
for (const cue in line) add(line[cue].speaker, cue, baseLine(cue), line[cue].takes);
const missing = entries.filter((e) => all || !fs.existsSync(path.join(project, 'assets', 'voice', e.speaker, e.cue + '_' + e.n + '.ogg')));
const bySpeaker = {};
for (const e of missing) (bySpeaker[e.speaker] = bySpeaker[e.speaker] || []).push(e);
let chars = 0;
for (const sp in bySpeaker) {
  bySpeaker[sp].sort((a, b) => (a.cue < b.cue ? -1 : a.cue > b.cue ? 1 : a.n - b.n));
  const c = bySpeaker[sp].reduce((s, e) => s + e.text.length, 0);
  chars += c;
  console.log(sp.padEnd(9), String(bySpeaker[sp].length).padStart(4), 'takes', String(c).padStart(6), 'characters');
}
console.log('TOTAL', entries.length, 'takes written,', missing.length, 'without a recording,', chars, 'characters');
if (ordersDir) {
  fs.mkdirSync(ordersDir, { recursive: true });
  for (const sp in bySpeaker) fs.writeFileSync(path.join(ordersDir, 'order_' + sp + '.json'), JSON.stringify(bySpeaker[sp], null, 1));
  fs.writeFileSync(path.join(ordersDir, 'order_all.json'), JSON.stringify(Object.values(bySpeaker).flat(), null, 1));
}
