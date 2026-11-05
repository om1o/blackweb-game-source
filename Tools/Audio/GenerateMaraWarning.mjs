import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

// Dependencies/model cache deliberately remain outside the distributable game.
const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const scratch = process.env.BLACKWEB_VOICE_SCRATCH || 'D:/BlackwebVoiceScratch';
const output = path.join(project, 'Godot/assets/generated');
const evidence = path.join(project, 'Evidence');
const dialogueFiles = ['mara_phone_warning_neural_v1.wav', 'luke_phone_reply_neural_v1.wav'];

// These two source sidecars are tracked so a fresh checkout retains lossless
// PCM16. This mode reapplies the setting after an intentional reimport without
// loading the model or changing the generated speech.
function configureImports(requireExisting = false) {
  for (const filename of dialogueFiles) {
    const importPath = path.join(output, `${filename}.import`);
    if (!fs.existsSync(importPath)) {
      if (requireExisting) throw new Error(`Import ${filename} in Godot once, then rerun --imports-only.`);
      console.log(`Import ${filename} in Godot once, then rerun this tool with --imports-only.`);
      continue;
    }
    const previous = fs.readFileSync(importPath, 'utf8');
    if (!/^compress\/mode=\d+$/m.test(previous)) throw new Error(`Missing compression setting in ${importPath}`);
    const updated = previous.replace(/^compress\/mode=\d+$/m, 'compress/mode=0');
    if (previous !== updated) fs.writeFileSync(importPath, updated);
  }
}
if (process.argv.includes('--imports-only')) {
  configureImports(true);
  console.log('Dialogue imports use PCM16; run Godot editor import to refresh its cache if changed.');
  process.exit(0);
}

const { KokoroTTS } = await import(pathToFileURL(path.join(scratch, 'node_modules/kokoro-js/dist/kokoro.js')));
const { env } = await import(pathToFileURL(path.join(scratch, 'node_modules/@huggingface/transformers/dist/transformers.node.mjs')));
env.cacheDir = path.join(scratch, 'hf-cache');
env.useBrowserCache = false;
const tts = await KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX', { dtype: 'q8', device: 'cpu' });
const rate = 24000;
const lines = [
  { speaker: 'Mara', text: 'Luke? If you get this, stay home.', voice: 'af_heart', speed: 0.96, start: 0, slot: 3.5 },
  { speaker: 'Mara', text: "Something's happening in Greyhaven. The streets are—", voice: 'af_heart', speed: 0.96, start: 3.5, slot: 4 },
  { speaker: 'Mara', text: "Don't come looking for me. Please. I can hear—", voice: 'af_heart', speed: 0.96, start: 7.5, slot: 4 },
  { speaker: 'Luke', text: "Mara. Pick up. ...I'm coming.", voice: 'am_michael', speed: 0.92, start: 13.5, slot: 3 },
];

function trim(samples) {
  let first = 0, last = samples.length - 1;
  while (first < last && Math.abs(samples[first]) < 0.003) first++;
  while (last > first && Math.abs(samples[last]) < 0.003) last--;
  return samples.slice(Math.max(0, first - Math.round(rate * 0.06)), Math.min(samples.length, last + Math.round(rate * 0.09)));
}

function phoneFilter(samples) {
  const filtered = new Float32Array(samples.length);
  const highPass = Math.exp(-2 * Math.PI * 150 / rate);
  const lowPass = 1 - Math.exp(-2 * Math.PI * 3700 / rate);
  let previous = 0, high = 0, low = 0;
  for (let i = 0; i < samples.length; i++) {
    high = highPass * (high + samples[i] - previous);
    previous = samples[i];
    low += lowPass * (high - low);
    const fadeIn = Math.min(1, i / (rate * 0.012));
    const fadeOut = Math.min(1, (samples.length - 1 - i) / (rate * 0.018));
    filtered[i] = low * fadeIn * fadeOut;
  }
  return filtered;
}

function normalize(samples, peakTarget = 0.75) {
  let peak = 0;
  for (const value of samples) peak = Math.max(peak, Math.abs(value));
  return samples.map(value => value * (peak ? peakTarget / peak : 1));
}

function pcm16(samples) {
  const wav = Buffer.alloc(44 + samples.length * 2);
  wav.write('RIFF', 0); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28); wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
  wav.write('data', 36); wav.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i])) * 32767), 44 + i * 2);
  return wav;
}

function stats(samples) {
  let peak = 0, sum = 0, squares = 0, clipped = 0;
  for (const value of samples) {
    peak = Math.max(peak, Math.abs(value)); sum += value; squares += value * value;
    if (Math.abs(value) >= 0.98) clipped++;
  }
  const rms = Math.sqrt(squares / samples.length);
  return { seconds: samples.length / rate, peak, peakDbfs: 20 * Math.log10(peak), rms, rmsDbfs: 20 * Math.log10(rms), dc: sum / samples.length, clippedSamples: clipped };
}

const segments = [];
for (const [index, line] of lines.entries()) {
  const audio = await tts.generate(line.text, { voice: line.voice, speed: line.speed });
  if (audio.sampling_rate !== rate) throw new Error(`Unexpected rate ${audio.sampling_rate}`);
  const raw = trim(audio.audio);
  const samples = normalize(line.speaker === 'Mara' ? phoneFilter(raw) : raw);
  fs.writeFileSync(path.join(scratch, `blackweb_warning_segment_${index}.wav`), pcm16(samples));
  segments.push({ ...line, samples, spokenSeconds: samples.length / rate });
  console.log(JSON.stringify({ ...line, spokenSeconds: samples.length / rate, fitsSlot: samples.length / rate <= line.slot - 0.05 }));
}

const overlong = segments.filter(line => line.spokenSeconds > line.slot - 0.05);
if (overlong.length) {
  fs.mkdirSync(evidence, { recursive: true });
  fs.writeFileSync(path.join(evidence, 'mara-warning-timing-review.json'), JSON.stringify(segments.map(({ samples, ...line }) => line), null, 2));
  throw new Error(`Natural speech exceeds current subtitle slots: ${overlong.map(line => `${line.speaker} ${line.spokenSeconds.toFixed(3)}s / ${line.slot}s`).join('; ')}. Review timing; do not crop spoken words.`);
}

const mara = new Float32Array(Math.round(rate * 11.5));
for (const line of segments.slice(0, 3)) mara.set(line.samples, Math.round(line.start * rate));
// A very quiet, short signal break closes the incomplete message. No music.
for (let i = 0; i < Math.round(rate * 0.035); i++) {
  const at = Math.round(rate * 11.45) + i;
  mara[at] += Math.sin(i * 1.73) * Math.sin(i * 0.37) * 0.012 * (1 - i / (rate * 0.035));
}
const reply = segments[3].samples;
const files = [
  ['mara_phone_warning_neural_v1.wav', mara],
  ['luke_phone_reply_neural_v1.wav', reply],
];
const report = { kind: 'Local fictional synthetic dialogue generation', model: 'onnx-community/Kokoro-82M-v1.0-ONNX', runtime: 'kokoro-js 1.2.1', dtype: 'q8', sampleRate: rate, format: 'mono PCM16', noVoiceCloning: true, segments: segments.map(({ samples, ...line }) => line), files: [] };
fs.mkdirSync(output, { recursive: true });
for (const [filename, samples] of files) {
  const wav = pcm16(samples);
  fs.writeFileSync(path.join(output, filename), wav);
  report.files.push({ filename, bytes: wav.length, sha256: createHash('sha256').update(wav).digest('hex'), ...stats(samples) });
}
fs.writeFileSync(path.join(evidence, 'mara-warning-audio-report.json'), JSON.stringify(report, null, 2));
configureImports();
console.log(JSON.stringify(report, null, 2));
