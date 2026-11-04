#!/usr/bin/env node
/**
 * Merge CUE4Parse's sampled USDA animations into its original skinned GLB.
 * Node built-ins only. Inputs stay untouched; output is a separate GLB.
 *
 * node merge_spider_animations.mjs --input Spider.glb --output SpiderAnimated.glb \
 *   --animation Idle=Spider_Idle.usda --animation Walk=Spider_Walk.usda \
 *   --animation Run=Spider_Run.usda
 * node merge_spider_animations.mjs --self-test
 *
 * This intentionally accepts the bounded grammar emitted by CUE4Parse commit
 * e76778c10ed25860e11ec488750753224d067d87, UsdAnimFormat/UsdaWriter.
 * It is not a general USD reader. Missing bones, different hierarchies, matrix
 * nodes, incomplete samples, nonfinite values, and nonunit quaternions fail.
 * All original binary bytes and JSON fields are retained. Only buffer length,
 * accessors, bufferViews, and animations are extended. No animation is invented.
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';

const JSON_CHUNK = 0x4e4f534a;
const BIN_CHUNK = 0x004e4942;
const fail = message => { throw new Error(message); };
const need = (condition, message) => { if (!condition) fail(message); };
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const align4 = value => Math.ceil(value / 4) * 4;

// Tokens keep strings separate from identifiers, so quoted joint names cannot
// accidentally be interpreted as properties or closing delimiters.
function tokenize(text) {
  const tokens = [];
  let i = 0;
  while (i < text.length) {
    if (/\s/.test(text[i])) { i++; continue; }
    if (text[i] === '#') { while (i < text.length && text[i] !== '\n') i++; continue; }
    if (text[i] === '"') {
      const start = i++;
      while (i < text.length) {
        if (text[i] === '\\') { i += 2; continue; }
        if (text[i++] === '"') break;
      }
      let value;
      try { value = JSON.parse(text.slice(start, i)); }
      catch { fail(`Invalid quoted USD string at character ${start}`); }
      tokens.push({ kind: 'string', value });
      continue;
    }
    const number = /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/.exec(text.slice(i));
    if (number) {
      const value = Number(number[0]);
      need(Number.isFinite(value), 'Nonfinite USD number');
      tokens.push({ kind: 'number', value });
      i += number[0].length;
      continue;
    }
    const identifier = /^[A-Za-z_][A-Za-z_0-9:.]*/.exec(text.slice(i));
    if (identifier) {
      tokens.push({ kind: 'identifier', value: identifier[0] });
      i += identifier[0].length;
      continue;
    }
    tokens.push({ kind: 'punctuation', value: text[i++] });
  }
  return tokens;
}

function readValue(tokens, state) {
  const token = tokens[state.i++];
  need(token, 'Unexpected end of USDA value');
  if (token.kind === 'number' || token.kind === 'string') return token.value;
  const closers = { '[': ']', '(': ')', '{': '}' };
  const close = closers[token.value];
  need(close, `Unsupported USDA value: ${token.value}`);
  const dictionary = token.value === '{';
  const values = [];
  while (tokens[state.i]?.value !== close) {
    need(tokens[state.i], `Unclosed USDA ${token.value}`);
    if (dictionary) {
      const key = tokens[state.i++];
      need(key.kind === 'number', 'Time-sample key must be numeric');
      need(tokens[state.i++]?.value === ':', 'Missing time-sample colon');
      values.push([key.value, readValue(tokens, state)]);
    } else values.push(readValue(tokens, state));
    if (tokens[state.i]?.value === ',') state.i++;
    else need(tokens[state.i]?.value === close, 'Missing comma in USDA value');
  }
  state.i++;
  return values;
}

function property(tokens, name) {
  const matches = [];
  for (let i = 0; i < tokens.length; i++) {
    if (tokens[i].kind === 'identifier' && tokens[i].value === name && tokens[i + 1]?.value === '=') {
      matches.push(readValue(tokens, { i: i + 2 }));
    }
  }
  need(matches.length === 1, `Expected exactly one ${name}; found ${matches.length}`);
  return matches[0];
}

export function parseCueAnimation(text, name) {
  need(text.replace(/^\uFEFF/, '').startsWith('#usda 1.0'), 'Expected a text USDA 1.0 file');
  const tokens = tokenize(text);
  const firstDef = tokens.findIndex(t => t.kind === 'identifier' && t.value === 'def');
  need(firstDef >= 0, 'No USDA prims');
  const stage = tokens.slice(0, firstDef);
  const fps = property(stage, 'timeCodesPerSecond');
  const start = property(stage, 'startTimeCode');
  const end = property(stage, 'endTimeCode');
  need(typeof fps === 'number' && fps > 0 && fps <= 100000, 'Invalid animation frame rate');
  need(start === 0 && Number.isInteger(end) && end >= 0, 'Expected CUE frame range starting at zero');

  const prims = [];
  for (let i = 0; i + 3 < tokens.length; i++) {
    if (tokens[i].value !== 'def' || tokens[i + 1].value !== 'SkelAnimation') continue;
    need(tokens[i + 2].kind === 'string' && tokens[i + 3].value === '{', 'Unsupported SkelAnimation declaration');
    let depth = 1;
    let j = i + 4;
    for (; j < tokens.length && depth; j++) {
      if (tokens[j].kind !== 'punctuation') continue;
      if (tokens[j].value === '{') depth++;
      if (tokens[j].value === '}') depth--;
    }
    need(depth === 0, 'Unclosed SkelAnimation');
    prims.push({ name: tokens[i + 2].value, body: tokens.slice(i + 4, j - 1) });
  }
  need(prims.length === 1, `Expected one SkelAnimation, found ${prims.length}`);
  const body = prims[0].body;
  const joints = property(body, 'joints');
  need(Array.isArray(joints) && joints.length > 0 && joints.every(j => typeof j === 'string' && j.length > 0), 'Invalid joints array');
  need(new Set(joints).size === joints.length, 'Duplicate USD joint paths');
  need(joints.every(j => !j.startsWith('/') && !j.endsWith('/') && !j.includes('//')), 'Invalid relative joint path');
  const result = { name: name ?? prims[0].name, sourceName: prims[0].name, fps, joints, frames: end + 1 };
  for (const [target, attribute, width] of [['translation', 'translations', 3], ['rotation', 'rotations', 4], ['scale', 'scales', 3]]) {
    const samples = property(body, `${attribute}.timeSamples`);
    need(Array.isArray(samples) && samples.length === result.frames, `${attribute}: frame count differs from the stage range`);
    result[target] = samples.map(([frame, values], index) => {
      need(frame === index, `${attribute}: sample frames must be contiguous and ordered from zero`);
      need(Array.isArray(values) && values.length === joints.length, `${attribute}, frame ${frame}: joint count mismatch`);
      return values.map((tuple, bone) => {
        need(Array.isArray(tuple) && tuple.length === width && tuple.every(v => typeof v === 'number' && Number.isFinite(v) && Number.isFinite(Math.fround(v))), `${attribute}, frame ${frame}, bone ${bone}: invalid tuple`);
        if (target === 'rotation') need(Math.abs(Math.hypot(...tuple) - 1) <= 0.02, `Nonunit quaternion at frame ${frame}, bone ${bone}`);
        return tuple;
      });
    });
  }
  return result;
}

export function readGlb(bytes) {
  need(bytes.length >= 20 && bytes.readUInt32LE(0) === 0x46546c67, 'Invalid GLB magic');
  need(bytes.readUInt32LE(4) === 2, 'Only GLB version 2 is supported');
  need(bytes.readUInt32LE(8) === bytes.length, 'GLB declared length differs from file length');
  const chunks = [];
  for (let offset = 12; offset < bytes.length;) {
    need(offset + 8 <= bytes.length, 'Truncated GLB chunk header');
    const size = bytes.readUInt32LE(offset);
    const type = bytes.readUInt32LE(offset + 4);
    need(size % 4 === 0 && offset + 8 + size <= bytes.length, 'Invalid GLB chunk size');
    chunks.push({ type, data: bytes.subarray(offset + 8, offset + 8 + size) });
    offset += 8 + size;
  }
  need(chunks[0]?.type === JSON_CHUNK && chunks.filter(c => c.type === JSON_CHUNK).length === 1, 'Expected one initial JSON chunk');
  need(chunks.filter(c => c.type === BIN_CHUNK).length === 1, 'Expected one embedded binary chunk');
  const document = JSON.parse(chunks[0].data.toString('utf8').trim());
  need(document.asset?.version === '2.0', 'Expected glTF 2.0');
  need(document.buffers?.length === 1 && !document.buffers[0].uri, 'Expected a single embedded GLB buffer');
  const binary = chunks.find(c => c.type === BIN_CHUNK).data;
  const length = document.buffers[0].byteLength;
  need(Number.isInteger(length) && length >= 0 && length <= binary.length && binary.length - length <= 3, 'Invalid embedded buffer length');
  return { document, binary, chunks };
}

function mapJoints(document, joints) {
  need(document.skins?.length === 1, 'Expected exactly one skin in the source GLB');
  const skin = document.skins[0];
  need(Array.isArray(document.nodes) && Array.isArray(skin.joints), 'Missing GLB skeleton');
  need(new Set(skin.joints).size === skin.joints.length, 'Duplicate GLB skin joints');
  const parents = new Map();
  document.nodes.forEach((node, parent) => {
    for (const child of node.children ?? []) {
      need(Number.isInteger(child) && child >= 0 && child < document.nodes.length, 'Invalid child node index');
      need(!parents.has(child), 'GLB node has multiple parents');
      parents.set(child, parent);
    }
  });
  const members = new Set(skin.joints);
  const paths = new Map();
  function jointPath(index, visiting = new Set()) {
    need(Number.isInteger(index) && index >= 0 && index < document.nodes.length, 'Invalid GLB joint node index');
    need(!visiting.has(index), 'Cyclic joint hierarchy');
    visiting.add(index);
    const node = document.nodes[index];
    need(typeof node.name === 'string' && node.name.length > 0 && !node.name.includes('/'), 'Every joint needs an unambiguous name');
    need(node.matrix === undefined, `Animated node ${node.name} uses a matrix instead of TRS`);
    const parent = parents.get(index);
    if (members.has(parent)) return `${jointPath(parent, visiting)}/${node.name}`;
    // Nonjoint armature roots are allowed, but hidden interstitial bones are not.
    let ancestor = parent;
    const ancestors = new Set();
    while (ancestor !== undefined) {
      need(!ancestors.has(ancestor), 'Cyclic armature hierarchy');
      ancestors.add(ancestor);
      need(!members.has(ancestor), `Nonjoint intermediate node above ${node.name}`);
      ancestor = parents.get(ancestor);
    }
    return node.name;
  }
  for (const index of skin.joints) {
    const fullPath = jointPath(index);
    need(!paths.has(fullPath), `Duplicate GLB joint path: ${fullPath}`);
    paths.set(fullPath, index);
  }
  const missing = joints.filter(joint => !paths.has(joint));
  const usdSet = new Set(joints);
  const extra = [...paths.keys()].filter(joint => !usdSet.has(joint));
  need(missing.length === 0 && extra.length === 0, `Skeleton mismatch. Missing GLB paths: ${missing.join(', ') || '(none)'}. Extra GLB paths: ${extra.join(', ') || '(none)'}`);
  return joints.map(joint => paths.get(joint));
}

function writeGlb(document, binary, originalChunks) {
  const jsonBytes = Buffer.from(JSON.stringify(document));
  const json = Buffer.alloc(align4(jsonBytes.length), 0x20);
  jsonBytes.copy(json);
  const chunks = originalChunks.map(chunk => ({ ...chunk, data: chunk.type === JSON_CHUNK ? json : chunk.type === BIN_CHUNK ? binary : chunk.data }));
  const size = 12 + chunks.reduce((sum, chunk) => sum + 8 + chunk.data.length, 0);
  need(size <= 0xffffffff, 'GLB exceeds the 32-bit file size limit');
  const output = Buffer.alloc(size);
  output.writeUInt32LE(0x46546c67, 0);
  output.writeUInt32LE(2, 4);
  output.writeUInt32LE(size, 8);
  let offset = 12;
  for (const chunk of chunks) {
    output.writeUInt32LE(chunk.data.length, offset);
    output.writeUInt32LE(chunk.type, offset + 4);
    chunk.data.copy(output, offset + 8);
    offset += chunk.data.length + 8;
  }
  return output;
}

export function mergeAnimations(glbBytes, clips) {
  need(clips.length > 0, 'No animations supplied');
  const original = readGlb(glbBytes);
  const document = structuredClone(original.document);
  document.bufferViews ??= [];
  document.accessors ??= [];
  document.animations ??= [];
  const usedNames = new Set(document.animations.map(a => a.name));
  const parts = [original.binary];
  let byteLength = original.binary.length;
  const report = [];
  function addAccessor(values, width, isTime = false) {
    need(values.length > 0 && values.length % width === 0, 'Invalid accessor value count');
    const bytes = Buffer.alloc(values.length * 4);
    values.forEach((value, i) => {
      need(Number.isFinite(value) && Number.isFinite(Math.fround(value)), 'Value cannot be represented as a glTF float');
      bytes.writeFloatLE(value, i * 4);
    });
    const view = document.bufferViews.length;
    document.bufferViews.push({ buffer: 0, byteOffset: byteLength, byteLength: bytes.length });
    const accessor = { bufferView: view, componentType: 5126, count: values.length / width, type: width === 1 ? 'SCALAR' : `VEC${width}` };
    if (isTime) { accessor.min = [Math.fround(values[0])]; accessor.max = [Math.fround(values.at(-1))]; }
    const index = document.accessors.length;
    document.accessors.push(accessor);
    parts.push(bytes);
    byteLength += bytes.length;
    return index;
  }
  for (const clip of clips) {
    need(typeof clip.name === 'string' && clip.name.length > 0 && !usedNames.has(clip.name), `Animation name is empty or already exists: ${clip.name}`);
    usedNames.add(clip.name);
    const nodes = mapJoints(document, clip.joints);
    const times = Array.from({ length: clip.frames }, (_, frame) => Math.fround(frame / clip.fps));
    need(times.every((time, i) => i === 0 || time > times[i - 1]), 'Sample times lose precision as glTF floats');
    const input = addAccessor(times, 1, true);
    const animation = { name: clip.name, channels: [], samplers: [], extras: { source: 'CUE4Parse USDA', sourceAnimation: clip.sourceName, sourceSha256: clip.sha256, frameRate: clip.fps, sampledFrames: clip.frames } };
    nodes.forEach((node, bone) => {
      for (const target of ['translation', 'rotation', 'scale']) {
        const values = [];
        let previousQuaternion;
        for (let frame = 0; frame < clip.frames; frame++) {
          const source = clip[target][frame][bone];
          let value;
          // CUE USD -> UE -> CUE GLB, including centimeters -> meters.
          if (target === 'translation') value = [source[0] * 0.01, source[2] * 0.01, -source[1] * 0.01];
          else if (target === 'scale') value = [source[0], source[2], source[1]];
          else {
            value = [-source[1], -source[3], source[2], -source[0]];
            const norm = Math.hypot(...value);
            value = value.map(v => v / norm);
            // Equivalent antipodes have identical poses; keep interpolation continuous.
            if (previousQuaternion && value.reduce((sum, v, i) => sum + v * previousQuaternion[i], 0) < 0) value = value.map(v => -v);
            previousQuaternion = value;
          }
          values.push(...value);
        }
        const sampler = animation.samplers.length;
        animation.samplers.push({ input, output: addAccessor(values, target === 'rotation' ? 4 : 3), interpolation: 'LINEAR' });
        animation.channels.push({ sampler, target: { node, path: target } });
      }
    });
    document.animations.push(animation);
    report.push({ name: clip.name, joints: nodes.length, frames: clip.frames, fps: clip.fps, sampledDurationSeconds: times.at(-1), channels: animation.channels.length });
  }
  document.buffers[0].byteLength = byteLength;
  const binary = Buffer.concat(parts, byteLength);
  const output = writeGlb(document, binary, original.chunks);
  const verified = readGlb(output);
  need(verified.binary.subarray(0, original.binary.length).equals(original.binary), 'Original binary preservation check failed');
  for (const key of Object.keys(original.document)) {
    if (!['accessors', 'bufferViews', 'buffers', 'animations'].includes(key)) assert.deepEqual(verified.document[key], original.document[key], `Original ${key} was changed`);
  }
  for (const key of ['accessors', 'bufferViews', 'animations']) assert.deepEqual(verified.document[key].slice(0, original.document[key]?.length ?? 0), original.document[key] ?? [], `Original ${key} changed`);
  return { output, report };
}

function selfTest() {
  const bin = Buffer.from([1, 2, 3, 4, 5, 6, 7, 8]);
  const doc = { asset: { version: '2.0' }, buffers: [{ byteLength: 8 }], nodes: [{ name: 'armature', children: [1] }, { name: 'Root', children: [2] }, { name: 'Leg' }], skins: [{ joints: [1, 2] }], meshes: [{ name: 'preserve-mesh' }], materials: [{ name: 'preserve-material' }], images: [{ name: 'preserve-image', bufferView: 0, mimeType: 'image/png' }], bufferViews: [{ buffer: 0, byteOffset: 0, byteLength: 8 }], extensions: { TEST_unknown: { keep: true } } };
  const source = writeGlb(doc, bin, [{ type: JSON_CHUNK }, { type: BIN_CHUNK }, { type: 0x12345678, data: Buffer.from([9, 10, 11, 12]) }]);
  const usd = '#usda 1.0\n( timeCodesPerSecond = 2 startTimeCode = 0 endTimeCode = 1 )\ndef SkelRoot "Spider" {\ndef SkelAnimation "Idle" {\nuniform token[] joints = ["Root", "Root/Leg"]\nfloat3[] translations.timeSamples = { 0: [(100,-200,300),(0,0,0)], 1: [(200,-200,300),(0,0,0)], }\nquatf[] rotations.timeSamples = { 0: [(1,0,0,0),(0.7071067811865476,0,0,-0.7071067811865476)], 1: [(-1,0,0,0),(-0.7071067811865476,0,0,0.7071067811865476)], }\nhalf3[] scales.timeSamples = { 0: [(1,2,3),(1,1,1)], 1: [(1,2,3),(1,1,1)], }\n} }';
  const clip = parseCueAnimation(usd, 'Idle');
  const { output, report } = mergeAnimations(source, [clip]);
  const result = readGlb(output);
  assert.equal(report[0].channels, 6);
  assert.equal(report[0].sampledDurationSeconds, 0.5);
  assert.deepEqual(result.chunks.at(-1).data, Buffer.from([9, 10, 11, 12]));
  const values = index => { const a = result.document.accessors[index]; const view = result.document.bufferViews[a.bufferView]; return Array.from({ length: view.byteLength / 4 }, (_, i) => result.binary.readFloatLE(view.byteOffset + i * 4)); };
  const animation = result.document.animations[0];
  assert.deepEqual(values(animation.samplers[0].input), [0, 0.5]);
  assert.deepEqual(values(animation.samplers[0].output), [1, 3, 2, 2, 3, 2]);
  assert.deepEqual(values(animation.samplers[2].output), [1, 3, 2, 1, 3, 2]);
  const rotation = values(animation.samplers[4].output);
  assert.ok(Math.abs(rotation[1] - Math.SQRT1_2) < 1e-6 && Math.abs(rotation[3] + Math.SQRT1_2) < 1e-6);
  assert.ok(rotation.slice(0, 4).every((value, i) => Math.abs(value - rotation[i + 4]) < 1e-7));
  assert.throws(() => mergeAnimations(source, [{ ...clip, joints: ['Root', 'Root/Missing'] }]), /Skeleton mismatch/);
  assert.throws(() => parseCueAnimation(usd.replace('(100,-200,300)', '(100,300)')), /invalid tuple/);
  assert.throws(() => parseCueAnimation(usd.replace('1: [(200', '2: [(200')), /contiguous/);
  assert.throws(() => parseCueAnimation(usd.replace('(1,0,0,0)', '(4,0,0,0)')), /Nonunit/);
  assert.throws(() => mergeAnimations(source, [clip, clip]), /already exists/);
  console.log(JSON.stringify({ selfTest: 'passed', checks: ['binary and JSON preservation', 'unknown chunk preservation', 'basis and units', 'time samples', 'quaternion continuity', 'bone mismatch rejection', 'malformed samples rejection', 'duplicate animation rejection'] }));
}

function main(args) {
  if (args.length === 1 && args[0] === '--self-test') { selfTest(); return; }
  const options = { animations: [], overwrite: false };
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--overwrite') { options.overwrite = true; continue; }
    need(['--input', '--output', '--animation'].includes(arg), `Unknown option: ${arg}`);
    const value = args[++i];
    need(value && !value.startsWith('--'), `Missing value for ${arg}`);
    if (arg === '--animation') options.animations.push(value);
    else { const key = arg.slice(2); need(!options[key], `Repeated ${arg}`); options[key] = value; }
  }
  need(options.input && options.output && options.animations.length > 0, 'Usage: --input Spider.glb --output SpiderAnimated.glb --animation Idle=Spider_Idle.usda [--animation Walk=...] [--overwrite]');
  const input = path.resolve(options.input);
  const output = path.resolve(options.output);
  need(input.toLowerCase() !== output.toLowerCase(), 'Output must differ from the source GLB');
  const sources = [];
  const clips = options.animations.map(specification => {
    const delimiter = specification.indexOf('=');
    need(delimiter > 0 && delimiter < specification.length - 1, '--animation must be Name=path.usda');
    const name = specification.slice(0, delimiter);
    const file = path.resolve(specification.slice(delimiter + 1));
    need(file.toLowerCase() !== output.toLowerCase(), 'Output cannot overwrite an animation source');
    const bytes = fs.readFileSync(file);
    const hash = sha256(bytes);
    sources.push({ name, file, sha256: hash });
    return { ...parseCueAnimation(bytes.toString('utf8'), name), sha256: hash };
  });
  const bytes = fs.readFileSync(input);
  const result = mergeAnimations(bytes, clips);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, result.output, { flag: options.overwrite ? 'w' : 'wx' });
  console.log(JSON.stringify({ input, inputSha256: sha256(bytes), output, outputSha256: sha256(result.output), bytes: result.output.length, sources, animations: result.report, preservedSourceBinary: true }, null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(`Animation merge failed: ${error.message}`); process.exitCode = 1; }
}
