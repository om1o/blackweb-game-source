// Preserve 4K masters, cap runtime maps at 2K, and record unique referenced bytes.
// Run after Godot's first asset import, then perform one editor reimport.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const files = [
  ...['color_4k.jpg','ao_4k.jpg','normal_opengl_4k.png','opacity_4k.jpg','roughness_4k.jpg'].map(n => 'Godot/assets/third_party/texturecan/cobweb_0015/others_0015_' + n),
  ...['Leaking012C','Leaking019C'].flatMap(id => ['NormalGL','Roughness'].map(map => `Godot/assets/third_party/ambientcg/${id}/${id}_4K-PNG_${map}.png`)),
  'Godot/assets/generated/blood_variants_v3.png',
  'Godot/assets/generated/goo_variants_v3.png',
];
const hashes = new Set();
const entries = files.map(file => {
  const full = path.join(root, file);
  const bytes = fs.readFileSync(full);
  const hash = crypto.createHash('sha256').update(bytes).digest('hex');
  if (hashes.has(hash)) throw new Error('Duplicate asset payload: ' + file);
  hashes.add(hash);
  const imported = full + '.import';
  if (!fs.existsSync(imported)) throw new Error('Run Godot import first: ' + file);
  let text = fs.readFileSync(imported, 'utf8');
  text = text.replace(/process\/size_limit=\d+/, 'process/size_limit=2048');
  text = text.replace(/mipmaps\/generate=(true|false)/, 'mipmaps/generate=true');
  // Data normals remain linear and use OpenGL (+Y) orientation.
  if (/NormalGL|normal_opengl/.test(file)) {
    text = text.replace(/compress\/mode=\d+/, 'compress/mode=2');
    text = text.replace(/compress\/normal_map=\d+/, 'compress/normal_map=1');
    text = text.replace(/process\/normal_map_invert_y=(true|false)/, 'process/normal_map_invert_y=false');
  }
  fs.writeFileSync(imported, text);
  return {path:file.replace(/^Godot\//,'res://'), bytes:bytes.length, sha256:hash, runtime_max_dimension:2048, mipmaps:true, runtime_compression:/NormalGL|normal_opengl/.test(file) ? 'VRAM RGTC normal map' : 'Lossless'};
});
const report = {scope:'Eleven new distinct, runtime-referenced environment-art payloads; excludes caches, alternate normal conventions, ZIPs, previous art, and duplicate files', source_bytes:entries.reduce((sum,f)=>sum+f.bytes,0), assets:entries};
fs.writeFileSync(path.join(root,'Docs/EnvironmentArtManifest.json'), JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({assets:entries.length, unique_source_bytes:report.source_bytes, runtime_max_dimension:2048}));
