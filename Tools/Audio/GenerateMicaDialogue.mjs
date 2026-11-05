import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

// Stock fictional voices, entirely local inference. No recordings or cloning.
const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const scratch = process.env.BLACKWEB_VOICE_SCRATCH || 'D:/BlackwebVoiceScratch';
const output = path.join(project, 'Godot/assets/generated');
const evidence = path.join(project, 'Evidence');
const rate = 24000;
const filenames = ['mica_phone_warning_neural_v1.wav', 'luke_mica_reply_neural_v1.wav', 'luke_web_reveal_neural_v3.wav', 'luke_voice_check_neural_v1.wav'];

function imports() {
  for (const filename of filenames) {
    const resource = `res://assets/generated/${filename}`;
    const cache = `res://.godot/imported/${filename}-${createHash('md5').update(resource).digest('hex')}.sample`;
    // Author the source sidecar before import: retain lossless mono PCM16.
    fs.writeFileSync(path.join(output, `${filename}.import`), `[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\npath="${cache}"\n\n[deps]\n\nsource_file="${resource}"\ndest_files=["${cache}"]\n\n[params]\n\nforce/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n`);
  }
}
if (process.argv.includes('--imports-only')) { imports(); process.exit(0); }
const { KokoroTTS } = await import(pathToFileURL(path.join(scratch, 'node_modules/kokoro-js/dist/kokoro.js')));
const { env } = await import(pathToFileURL(path.join(scratch, 'node_modules/@huggingface/transformers/dist/transformers.node.mjs')));
env.cacheDir = path.join(scratch, 'hf-cache');
env.useBrowserCache = false;
const tts = await KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX', { dtype: 'q8', device: 'cpu' });
const lines = [
  { id: 'home', speaker: 'Mica', text: "Luke? It's Mica. You're home.", voice: 'af_heart', speed: 0.96 },
  { id: 'vault_keys', speaker: 'Mica', text: 'Listen carefully. The keys are for the vault.', voice: 'af_heart', speed: 0.96 },
  { id: 'plant_hint', speaker: 'Mica', text: 'I left the code by the plant—', voice: 'af_heart', speed: 0.96 },
  { id: 'reply', speaker: 'Luke', text: 'Mica? ... Mica!', voice: 'am_michael', speed: 0.92 },
  { id: 'web_reaction', speaker: 'Luke', text: 'Mica... these webs were not here yesterday.', voice: 'am_michael', speed: 0.92 },
  { id: 'voice_check', speaker: 'Luke', text: 'Can you hear me? This is the voice check.', voice: 'am_michael', speed: 0.92 },
];
function trim(samples) {
  let first = 0, last = samples.length - 1;
  while (first < last && Math.abs(samples[first]) < 0.003) first++;
  while (last > first && Math.abs(samples[last]) < 0.003) last--;
  return samples.slice(Math.max(0, first - Math.round(rate * .06)), Math.min(samples.length, last + Math.round(rate * .09)));
}
function phoneFilter(samples) {
  const filtered = new Float32Array(samples.length);
  const highPass = Math.exp(-2 * Math.PI * 120 / rate), lowPass = 1 - Math.exp(-2 * Math.PI * 4500 / rate);
  let previous = 0, high = 0, low = 0;
  for (let i = 0; i < samples.length; i++) {
    high = highPass * (high + samples[i] - previous); previous = samples[i];
    low += lowPass * (high - low);
    filtered[i] = low * Math.min(1, i / (rate * .012)) * Math.min(1, (samples.length - 1 - i) / (rate * .018));
  }
  return filtered;
}
function normalize(samples) {
  // Mild soft compression raises quiet syllables without hard clipping; −3 dBFS peak.
  const compressed = samples.map(value => Math.tanh(value * 2.0));
  let peak = 0;
  for (const value of compressed) peak = Math.max(peak, Math.abs(value));
  return compressed.map(value => value * (peak ? .707 / peak : 1));
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
  for (const value of samples) { peak = Math.max(peak, Math.abs(value)); sum += value; squares += value * value; if (Math.abs(value) >= .98) clipped++; }
  const rms = Math.sqrt(squares / samples.length);
  return { duration_seconds: samples.length / rate, peak, peak_dbfs: 20 * Math.log10(peak), rms, rms_dbfs: 20 * Math.log10(rms), dc: sum / samples.length, clipped_samples: clipped };
}
const segments = [];
for (const line of lines) {
  const audio = await tts.generate(line.text, { voice: line.voice, speed: line.speed });
  if (audio.sampling_rate !== rate) throw new Error(`Unexpected sample rate: ${audio.sampling_rate}`);
  const samples = normalize(line.speaker === 'Mica' ? phoneFilter(trim(audio.audio)) : trim(audio.audio));
  fs.writeFileSync(path.join(scratch, `blackweb_mica_${line.id}.wav`), pcm16(samples));
  segments.push({ ...line, samples, ...stats(samples) });
  console.log(`${line.id}: ${(samples.length / rate).toFixed(3)}s`);
}
// Timings derive from the whole spoken takes. Never truncate words to fit old slots.
let cursor = 0;
for (const [index, segment] of segments.slice(0, 3).entries()) {
  segment.start_seconds = cursor;
  segment.subtitle_seconds = Math.ceil((segment.duration_seconds + (index === 2 ? .12 : .30)) * 1000) / 1000;
  cursor += segment.subtitle_seconds;
}
const warning = new Float32Array(Math.round(cursor * rate));
for (const segment of segments.slice(0, 3)) warning.set(segment.samples, Math.round(segment.start_seconds * rate));
// Brief phone cutoff follows the complete word "plant"; no code is spoken.
for (let i = 0; i < Math.round(rate * .035); i++) warning[warning.length - Math.round(rate * .055) + i] += Math.sin(i * 1.73) * Math.sin(i * .37) * .025 * (1 - i / (rate * .035));
const gap = 1.20;
segments[3].start_seconds = warning.length / rate + gap;
segments[3].subtitle_seconds = Math.ceil((segments[3].duration_seconds + .40) * 1000) / 1000;
const files = [[filenames[0], warning], [filenames[1], segments[3].samples], [filenames[2], segments[4].samples], [filenames[3], segments[5].samples]];
const fileReports = [];
fs.mkdirSync(output, { recursive: true }); fs.mkdirSync(evidence, { recursive: true });
for (const [filename, samples] of files) {
  const wav = pcm16(samples); fs.writeFileSync(path.join(output, filename), wav);
  fileReports.push({ path: `res://assets/generated/${filename}`, bytes: wav.length, sha256: createHash('sha256').update(wav).digest('hex'), ...stats(samples) });
}
const metadata = {
  version: 1, caller: 'Mica',
  lines: [...segments.slice(0, 3).map(line => `${line.speaker}: ${line.text}`), '[Connection lost]', `Luke: ${segments[3].text}`],
  durations: [...segments.slice(0, 3).map(line => line.subtitle_seconds), gap, segments[3].subtitle_seconds],
  warning: { ...fileReports[0], start_seconds: 0 },
  reply: { ...fileReports[1], start_seconds: segments[3].start_seconds },
  web_reaction: { ...fileReports[2], subtitle: `Luke: ${segments[4].text}` },
  voice_test: { ...fileReports[3], subtitle: segments[5].text },
  segments: segments.map(({ samples, ...segment }) => segment),
  policy: 'The call cuts after plant. The paper by the plant reveals the vault code; no code appears in speech or phone subtitles.',
  provenance: { model: 'onnx-community/Kokoro-82M-v1.0-ONNX', model_source: 'https://huggingface.co/hexgrad/Kokoro-82M', runtime: 'kokoro-js 1.2.1', dtype: 'q8', voices: ['af_heart', 'am_michael'], local_inference: true, voice_cloning: false, format: '24 kHz mono PCM16', performance: 'Stock synthetic voice, not a human actor performance' },
};
fs.writeFileSync(path.join(project, 'Godot/data/phone_dialogue.json'), JSON.stringify(metadata, null, 2) + '\n');
fs.writeFileSync(path.join(evidence, 'mica-dialogue-audio-report.json'), JSON.stringify(metadata, null, 2) + '\n');
imports();
console.log(JSON.stringify({ lines: metadata.lines, durations: metadata.durations, warning: metadata.warning, reply: metadata.reply }, null, 2));
