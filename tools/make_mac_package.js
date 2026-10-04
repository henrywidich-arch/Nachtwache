// Packs the game for a Mac: the project folder without Godot's cache, without the
// Windows start scripts and without Godot itself (the Mac user loads Godot for macOS from
// godotengine.org). Unlike a ZIP made by Windows' own tools, this one says of every file
// what it may do on a Unix system, so SPIELEN.command arrives as something that can be
// started.
//   node tools/make_mac_package.js [output.zip]
// Default output: <parent folder>/<project folder>-Koop-Paket-Mac.zip
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const root = path.resolve(__dirname, '..');
const folder = path.basename(root);
const out = path.resolve(process.argv[2] || path.join(root, '..', folder + '-Koop-Paket-Mac.zip'));
// Left out: the cache every machine builds for itself, and what only Windows can start.
const skipDirs = new Set(['.godot', '.git']);
const skipFile = name => /\.(cmd|bat)$/i.test(name);
// Already compressed: stored as they are.
const stored = /\.(png|jpg|jpeg|ogg|mp3|glb|zip|webp)$/i;

function walk(dir, list) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (!skipDirs.has(entry.name)) walk(full, list);
    } else if (entry.isFile() && !skipFile(entry.name)) {
      list.push(full);
    }
  }
  return list;
}

function dosTime(date) {
  const time = (date.getHours() << 11) | (date.getMinutes() << 5) | (date.getSeconds() >> 1);
  const day = ((date.getFullYear() - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate();
  return [time, day];
}

const files = walk(root, []);
const fd = fs.openSync(out, 'w');
let offset = 0;
const central = [];
let raw = 0;
for (const file of files) {
  const name = Buffer.from(folder + '/' + path.relative(root, file).split(path.sep).join('/'), 'utf8');
  const data = fs.readFileSync(file);
  // A script that is to be started must not carry Windows line ends.
  if (/\.command$/.test(file) && data.includes(13)) throw new Error(file + ' has Windows line ends');
  const packed = stored.test(file) ? data : zlib.deflateRawSync(data, { level: 6 });
  const method = packed === data ? 0 : 8;
  const crc = zlib.crc32(data);
  const [time, day] = dosTime(fs.statSync(file).mtime);
  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50, 0);
  local.writeUInt16LE(20, 4);
  local.writeUInt16LE(0x0800, 6);
  local.writeUInt16LE(method, 8);
  local.writeUInt16LE(time, 10);
  local.writeUInt16LE(day, 12);
  local.writeUInt32LE(crc, 14);
  local.writeUInt32LE(packed.length, 18);
  local.writeUInt32LE(data.length, 22);
  local.writeUInt16LE(name.length, 26);
  local.writeUInt16LE(0, 28);
  fs.writeSync(fd, local);
  fs.writeSync(fd, name);
  fs.writeSync(fd, packed);
  // Unix: a regular file, readable by all; the start script may also be run.
  const mode = /\.command$/.test(file) ? 0o100755 : 0o100644;
  const entry = Buffer.alloc(46);
  entry.writeUInt32LE(0x02014b50, 0);
  entry.writeUInt16LE((3 << 8) | 30, 4);
  entry.writeUInt16LE(20, 6);
  entry.writeUInt16LE(0x0800, 8);
  entry.writeUInt16LE(method, 10);
  entry.writeUInt16LE(time, 12);
  entry.writeUInt16LE(day, 14);
  entry.writeUInt32LE(crc, 16);
  entry.writeUInt32LE(packed.length, 20);
  entry.writeUInt32LE(data.length, 24);
  entry.writeUInt16LE(name.length, 28);
  entry.writeUInt32LE((mode << 16) >>> 0, 38);
  entry.writeUInt32LE(offset, 42);
  central.push(Buffer.concat([entry, name]));
  offset += 30 + name.length + packed.length;
  raw += data.length;
}
if (files.length > 65535 || offset > 0xfffffff0) throw new Error('too big for a plain ZIP');
const directory = Buffer.concat(central);
fs.writeSync(fd, directory);
const end = Buffer.alloc(22);
end.writeUInt32LE(0x06054b50, 0);
end.writeUInt16LE(files.length, 8);
end.writeUInt16LE(files.length, 10);
end.writeUInt32LE(directory.length, 12);
end.writeUInt32LE(offset, 16);
fs.writeSync(fd, end);
fs.closeSync(fd);
console.log('%d Dateien, %d MB -> %s (%d MB)', files.length, Math.round(raw / 1048576), out, Math.round((offset + directory.length + 22) / 1048576));
