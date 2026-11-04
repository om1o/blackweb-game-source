#!/usr/bin/env node
// Configure standalone CUE PNG normals before Godot imports them. No pixel edits.
// Usage: node prepare_normal_imports.mjs --asset-root <RecoveredAssets>
//   --materials <runtime-house-material-packages.txt> [--apply] [--report <json>]
// Without --apply, prints the bounded changes only. Embedded GLBs are untouched.
import fs from 'node:fs';
import path from 'node:path';

const keys = new Set(['normal', 'normals', 'normaltexture', 'normalmap', '12.normal', 'pm_normals']);
const opts = {};
for (let i = 2; i < process.argv.length; i++) {
  const arg = process.argv[i];
  if (arg === '--apply') opts.apply = true;
  else if (['--asset-root', '--materials', '--report'].includes(arg)) opts[arg.slice(2)] = process.argv[++i];
  else throw new Error(`Unknown option: ${arg}`);
}
if (!opts['asset-root'] || !opts.materials) throw new Error('Required: --asset-root <RecoveredAssets> --materials <package-list.txt> [--apply]');
const assetRoot = fs.realpathSync(opts['asset-root']);
const report = { applied: !!opts.apply, convention: 'Standalone CUE TextureExporter PNG: DirectX Y-. Godot import converts once to OpenGL Y+. Embedded GLB normal images already converted and remain untouched.', configured: [], unchanged: [], missingTextures: [], missingMaterialFiles: [] };
const seen = new Set();
const normalSources = new Set();
function sourcePath(value) {
  const text = typeof value === 'object' && value ? (value.ObjectPath ?? value.AssetPathName) : value;
  if (typeof text !== 'string') return '';
  return text.match(/\/(?:Game|Engine)\/[^.'"\s]+/)?.[0] ?? '';
}
function relative(source) {
  if (source.startsWith('/Game/')) return 'Arachnophobia/Content/' + source.slice(6);
  if (source.startsWith('/Engine/')) return 'Engine/Content/' + source.slice(8);
  throw new Error(`Unsupported material source: ${source}`);
}
function safeJoin(rel) {
  const result = path.resolve(assetRoot, rel);
  if (result !== assetRoot && !result.toLowerCase().startsWith(assetRoot.toLowerCase() + path.sep)) throw new Error('Asset path escaped the recovery root');
  return result;
}
function readJson(file) {
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
}
function inspectMaterial(source, depth = 0) {
  if (seen.has(source)) return;
  if (depth > 16) throw new Error('Material parent chain exceeded 16 levels');
  seen.add(source);
  const rel = relative(source);
  const resolved = readJson(safeJoin(rel + '.json'));
  const raw = readJson(safeJoin('Metadata/' + rel + '.uasset.json'));
  if (!resolved && !raw) report.missingMaterialFiles.push(source);
  for (const [name, value] of Object.entries(resolved?.Textures ?? {})) if (keys.has(name.toLowerCase())) {
    const normal = sourcePath(value);
    if (normal) normalSources.add(normal);
  }
  for (const item of Array.isArray(raw) ? raw : []) {
    if (!String(item.Type ?? '').startsWith('Material') || item.Name !== source.split('/').at(-1)) continue;
    const props = item.Properties ?? {};
    const cached = item.CachedExpressionData ?? {};
    const cachedInfo = cached['RuntimeEntries[3]']?.ParameterInfoSet ?? [];
    const cachedTextures = cached.TextureValues ?? [];
    const referencedNormal = {
      '/Game/OldBrickHouse/Materials/Masters/M_GlassJars': 'T_GlassJars_N',
      '/Game/OldBrickHouse/Materials/Masters/M_Plants': 'T_Plants_N'
    }[source];
    if (referencedNormal) for (const value of [...(cached.ReferencedTextures ?? []), ...(item.ReferencedTextures ?? [])]) {
      const normal = sourcePath(value);
      if (normal.split('/').at(-1) === referencedNormal) normalSources.add(normal);
    }
    if (cachedInfo.length === cachedTextures.length) cachedInfo.forEach((info, index) => {
      if (!keys.has(String(info.Name ?? '').toLowerCase())) return;
      const normal = sourcePath(cachedTextures[index]);
      if (normal) normalSources.add(normal);
    });
    for (const param of props.TextureParameterValues ?? []) if (keys.has(String(param.ParameterInfo?.Name ?? '').toLowerCase())) {
      const normal = sourcePath(param.ParameterValue);
      if (normal) normalSources.add(normal);
    }
    const parent = sourcePath(props.Parent);
    if (parent) inspectMaterial(parent, depth + 1);
  }
}
function setSetting(text, section, key, value) {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  let start = lines.findIndex(line => line.trim() === `[${section}]`);
  if (start < 0) { lines.push('', `[${section}]`, `${key}=${value}`); return lines.join('\n'); }
  let end = start + 1;
  while (end < lines.length && !/^\s*\[/.test(lines[end])) end++;
  const index = lines.findIndex((line, i) => i > start && i < end && line.split('=', 1)[0].trim() === key);
  if (index >= 0) lines[index] = `${key}=${value}`;
  else lines.splice(end, 0, `${key}=${value}`);
  return lines.join('\n');
}
for (const line of fs.readFileSync(opts.materials, 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/)) {
  const item = line.trim();
  if (!item || item.startsWith('#')) continue;
  const source = item.startsWith('Arachnophobia/Content/') ? '/Game/' + item.slice('Arachnophobia/Content/'.length).replace(/\.uasset$/, '') : sourcePath(item);
  if (!source) throw new Error(`Invalid material package line: ${item}`);
  inspectMaterial(source);
}
for (const source of [...normalSources].sort()) {
  const rel = relative(source) + '.png';
  const texture = safeJoin(rel);
  if (!fs.existsSync(texture)) { report.missingTextures.push({ source, file: texture }); continue; }
  const file = texture + '.import';
  const original = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  let modified = original || '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\nsource_file=' + JSON.stringify('res://assets/recovered/' + rel) + '\n\n[params]\n';
  for (const [key, value] of Object.entries({ 'process/normal_map_invert_y': 'true', 'process/channel_remap/green': '1', 'process/fix_alpha_border': 'false', 'compress/normal_map': '1', 'mipmaps/generate': 'true' })) modified = setSetting(modified, 'params', key, value);
  modified = modified.trimEnd() + '\n';
  if (modified === original.replace(/\r\n/g, '\n')) { report.unchanged.push(file); continue; }
  const backup = original ? file + '.before-blackweb-normal' : null;
  if (opts.apply) {
    if (backup && !fs.existsSync(backup)) fs.writeFileSync(backup, original, { flag: 'wx' });
    fs.writeFileSync(file, modified);
  }
  report.configured.push({ source, file, created: !original, backup });
}
report.materialsInspected = seen.size;
report.normalTexturesReferenced = normalSources.size;
const serialized = JSON.stringify(report, null, 2) + '\n';
if (opts.report) { fs.mkdirSync(path.dirname(path.resolve(opts.report)), { recursive: true }); fs.writeFileSync(opts.report, serialized); }
process.stdout.write(serialized);
