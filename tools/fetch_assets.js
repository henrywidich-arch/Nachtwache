// Fetches the free textures and models of mission two from Poly Haven (polyhaven.com,
// all CC0) as listed in assets/hive/sources.json, and writes assets/hive/CREDITS.md.
//   node tools/fetch_assets.js [--dry] [--budget=400]
// Textures land in assets/hive/tex/<id>_diff.jpg, _nor.jpg (OpenGL), _arm.jpg (ambient
// occlusion, roughness, metal in red, green, blue; older ones have _rough.jpg instead);
// models in assets/hive/models/<id>/ as glTF with their own textures. What is there
// already is not fetched again. Every picture gets import settings (see below).
const fs = require('fs');
const path = require('path');
const https = require('https');

const root = path.join(__dirname, '..', 'assets', 'hive');
const sources = JSON.parse(fs.readFileSync(path.join(root, 'sources.json'), 'utf8'));
const dry = process.argv.includes('--dry');
const budget = Number((process.argv.find(a => a.startsWith('--budget=')) || '--budget=400').slice(9)) * 1024 * 1024;

function get(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'Nachtwache-asset-fetch' } }, response => {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        get(response.headers.location).then(resolve, reject);
        return;
      }
      if (response.statusCode !== 200) {
        reject(new Error(url + ' -> ' + response.statusCode));
        return;
      }
      const parts = [];
      response.on('data', part => parts.push(part));
      response.on('end', () => resolve(Buffer.concat(parts)));
    }).on('error', reject);
  });
}

// Import settings for every picture that has none yet: compressed for the graphics card,
// with mipmaps; a normal map is marked as one. (Godot's defaults keep such pictures
// uncompressed and without mipmaps, which costs memory and flickers in the distance.)
function write_import_settings() {
  const plain = fs.readFileSync(path.join(root, '..', 'models', 'cruelite_diffuse.jpg.import'), 'utf8');
  const bumpy = fs.readFileSync(path.join(root, '..', 'models', 'cruelite_normal.png.import'), 'utf8');
  let written = 0;
  const walk = dir => {
    for (const name of fs.readdirSync(dir)) {
      const file = path.join(dir, name);
      if (fs.statSync(file).isDirectory()) {
        walk(file);
        continue;
      }
      if (!/\.(jpg|png)$/i.test(name) || fs.existsSync(file + '.import')) continue;
      const template = /_nor(_gl)?(_\dk)?\./.test(name) ? bumpy : plain;
      const res = 'res://' + path.relative(path.join(root, '..', '..'), file).split(path.sep).join('/');
      const head = ['[remap]', '', 'importer="texture"', 'type="CompressedTexture2D"', '', '[deps]', '', 'source_file="' + res + '"', '', ''].join('\n');
      fs.writeFileSync(file + '.import', head + template.slice(template.indexOf('[params]')));
      written += 1;
    }
  };
  walk(root);
  console.log(written + ' import settings written');
}

async function main() {
  let total = 0;
  const wanted = [];
  // What each asset needs: [url, bytes, file in the project].
  for (const entry of sources.textures) {
    const id = entry.id;
    const size = entry.size || sources.texture_size || '1k';
    const files = JSON.parse((await get('https://api.polyhaven.com/files/' + id)).toString());
    // Older assets have no packed map: then the roughness alone is taken.
    const maps = [['Diffuse', 'diff'], ['nor_gl', 'nor'], files.arm && files.arm[size] ? ['arm', 'arm'] : ['Rough', 'rough']];
    for (const [map, suffix] of maps) {
      if (!files[map] || !files[map][size]) throw new Error(id + ' has no ' + map + ' at ' + size);
      const file = files[map][size].jpg;
      wanted.push([file.url, file.size, path.join(root, 'tex', id + '_' + suffix + '.jpg')]);
    }
  }
  for (const entry of sources.models) {
    const id = entry.id;
    const size = entry.size || sources.model_size || '1k';
    const files = JSON.parse((await get('https://api.polyhaven.com/files/' + id)).toString());
    const gltf = files.gltf[size].gltf;
    wanted.push([gltf.url, gltf.size, path.join(root, 'models', id, id + '.gltf')]);
    for (const [inside, file] of Object.entries(gltf.include || {})) {
      wanted.push([file.url, file.size, path.join(root, 'models', id, inside)]);
    }
  }
  const missing = wanted.filter(item => !fs.existsSync(item[2]) || fs.statSync(item[2]).size !== item[1]);
  for (const item of wanted) total += item[1];
  const todo = missing.reduce((sum, item) => sum + item[1], 0);
  console.log(wanted.length + ' files, ' + (total / 1048576).toFixed(1) + ' MB in all; to fetch: ' + missing.length + ' files, ' + (todo / 1048576).toFixed(1) + ' MB');
  if (total > budget) throw new Error('over the budget of ' + (budget / 1048576).toFixed(0) + ' MB');
  if (dry) return;
  let done = 0;
  for (const [url, size, file] of missing) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const data = await get(url);
    if (data.length !== size) throw new Error(url + ': ' + data.length + ' bytes instead of ' + size);
    fs.writeFileSync(file, data);
    done += 1;
    if (done % 20 === 0) console.log('  ' + done + ' / ' + missing.length);
  }
  write_import_settings();
  const lines = ['# Fremde Assets von Mission 2', '', 'Alle Texturen und Modelle in diesem Ordner stammen von **Poly Haven** (https://polyhaven.com) und stehen unter **CC0** (gemeinfrei, keine Namensnennung nötig). Geholt mit `node tools/fetch_assets.js` nach der Liste in `sources.json`.', '', '## Texturen', ''];
  for (const entry of sources.textures) lines.push('- `' + entry.id + '` – https://polyhaven.com/a/' + entry.id + (entry.use ? ' – ' + entry.use : ''));
  lines.push('', '## Modelle', '');
  for (const entry of sources.models) lines.push('- `' + entry.id + '` – https://polyhaven.com/a/' + entry.id + (entry.use ? ' – ' + entry.use : ''));
  lines.push("", "## Eigene Modelle", "", "Im Ordner `user/` liegen fünf eigene Modelle des Projekts (mit Meshy erzeugt, für das Spiel vereinfacht und neu texturiert): `lab_table_a`, `lab_table_b`, `microscope_a`, `microscope_b` und `door`. Sie stammen nicht von Poly Haven.");
  fs.writeFileSync(path.join(root, 'CREDITS.md'), lines.join('\n') + '\n');
  console.log('fetched ' + done + ' files; CREDITS.md written');
}

main().catch(error => {
  console.error('FAILED: ' + error.message);
  process.exit(1);
});
