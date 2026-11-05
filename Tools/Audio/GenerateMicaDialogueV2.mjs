import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

// Fresh full-context stock synthesis. No actor recording, identity or cloning.
// Neural caches stay outside the distributable project. Existing takes survive.
const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const scratch = process.env.BLACKWEB_VOICE_SCRATCH || 'D:/BlackwebVoiceScratch';
const generated = path.join(project, 'Godot/assets/generated');
const sources = path.join(generated, 'voice_sources');
const evidence = path.join(project, 'Evidence');
const rate = 24000;
for (const directory of [sources, evidence]) fs.mkdirSync(directory, { recursive: true });
const modelId = 'onnx-community/Kokoro-82M-v1.0-ONNX';
const takes = [
  { id: 'mica', voice: 'af_heart', speed: 0.98, text: "Luke? It's Mica. You're home. Listen carefully. The keys are for the vault. I left the code by the plant—" },
  { id: 'luke_reply', voice: 'am_michael', speed: 0.96, text: 'Mica? ... Mica!' },
  { id: 'luke_web', voice: 'am_michael', speed: 0.96, text: 'Mica... these webs were not here yesterday.' },
  { id: 'voice_check', voice: 'am_michael', speed: 0.96, text: 'Can you hear me? This is the voice check.' },
];

function pcm16(samples) {
  const wav = Buffer.alloc(44 + samples.length * 2);
  wav.write('RIFF', 0); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28); wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
  wav.write('data', 36); wav.writeUInt32LE(samples.length * 2, 40);
  samples.forEach((value, i) => wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, value)) * 32767), 44 + i * 2));
  return wav;
}
function readWav(filename) {
  const bytes = fs.readFileSync(filename);
  if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.readUInt32LE(24) !== rate || bytes.readUInt16LE(22) !== 1) throw new Error('Expected 24kHz mono WAV');
  let cursor = 12;
  while (cursor + 8 < bytes.length) {
    const size = bytes.readUInt32LE(cursor + 4);
    if (bytes.toString('ascii', cursor, cursor + 4) === 'data') return Float32Array.from({ length: size / 2 }, (_, i) => bytes.readInt16LE(cursor + 8 + i * 2) / 32768);
    cursor += 8 + size + size % 2;
  }
  throw new Error('No WAV sample data');
}
function stats(samples) {
  let peak = 0, sum = 0, squares = 0, clipped = 0;
  for (const value of samples) { peak = Math.max(peak, Math.abs(value)); sum += value; squares += value * value; if (Math.abs(value) >= .98) clipped++; }
  const rms = Math.sqrt(squares / samples.length);
  return { duration_seconds: samples.length / rate, peak, peak_dbfs: 20 * Math.log10(peak), rms, rms_dbfs: 20 * Math.log10(rms), dc: sum / samples.length, clipped_samples: clipped };
}
function report(filename, samples) {
  fs.writeFileSync(filename, pcm16(samples));
  return inspect(filename);
}
function inspect(filename) {
  const wav = fs.readFileSync(filename);
  return { path: `res://${path.relative(path.join(project, 'Godot'), filename).replaceAll('\\', '/')}`, bytes: wav.length, sha256: createHash('sha256').update(wav).digest('hex'), ...stats(readWav(filename)) };
}
function trim(samples) {
  let first = 0, last = samples.length - 1;
  while (first < last && Math.abs(samples[first]) < .0015) first++;
  while (last > first && Math.abs(samples[last]) < .0015) last--;
  return samples.slice(Math.max(0, first - Math.round(rate * .07)), Math.min(samples.length, last + Math.round(rate * .10)));
}
function join(chunks) {
  const result = new Float32Array(chunks.reduce((sum, chunk) => sum + chunk.length, 0));
  let cursor = 0;
  for (const chunk of chunks) { result.set(chunk, cursor); cursor += chunk.length; }
  return result;
}
function silence(seconds) { return new Float32Array(Math.round(seconds * rate)); }
function resample16(samples) {
  return Float32Array.from({ length: Math.floor(samples.length * 2 / 3) }, (_, i) => {
    const at = i * 1.5, left = Math.floor(at), blend = at - left;
    return samples[left] * (1 - blend) + (samples[Math.min(left + 1, samples.length - 1)] * blend);
  });
}

const { env, pipeline } = await import(pathToFileURL(path.join(scratch, 'node_modules/@huggingface/transformers/dist/transformers.node.mjs')));
env.cacheDir = path.join(scratch, 'hf-cache');
env.useBrowserCache = false;
if (!process.argv.includes('--reuse-takes')) {
  const { KokoroTTS } = await import(pathToFileURL(path.join(scratch, 'node_modules/kokoro-js/dist/kokoro.js')));
  console.log('Loading local fp32 Kokoro; cache remains outside game project');
  const tts = await KokoroTTS.from_pretrained(modelId, { dtype: 'fp32', device: 'cpu', progress_callback: item => { if (item.status === 'done') console.log(`Cached ${item.file}`); } });
  for (const take of takes) {
    if (process.argv.includes('--only-luke') && !take.id.startsWith('luke')) {
      take.source = inspect(path.join(sources, `${take.id}_full_context_dry_v2.wav`));
      continue;
    }
    const audio = await tts.generate(take.text, { voice: take.voice, speed: take.speed });
    if (audio.sampling_rate !== rate) throw new Error('Unexpected synthesis sample rate');
    take.source = report(path.join(sources, `${take.id}_full_context_dry_v2.wav`), trim(audio.audio));
    console.log(`${take.id} dry take: ${take.source.duration_seconds.toFixed(3)}s`);
  }
  await tts.model.dispose();
} else {
  for (const take of takes) take.source = inspect(path.join(sources, `${take.id}_full_context_dry_v2.wav`));
}
console.log('Aligning complete words with local Whisper tiny.en; this is an intelligibility check, not a listening judgment');
let transcriber;
for (let attempt = 0; attempt < 3; attempt++) {
  try {
    transcriber = await pipeline('automatic-speech-recognition', 'Xenova/whisper-tiny.en', { dtype: 'q8', device: 'cpu', progress_callback: item => { if (item.status === 'done') console.log(`Cached ${item.file}`); } });
    break;
  } catch (error) {
    if (attempt === 2) throw error;
    console.log(`Waiting for newly downloaded ONNX cache files to close (${attempt + 1}/2)`);
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
}
const previousAlignmentPath = path.join(evidence, 'voice-v2-source-alignment.json');
const previousAlignment = process.argv.includes('--reuse-alignment') && fs.existsSync(previousAlignmentPath) ? JSON.parse(fs.readFileSync(previousAlignmentPath, 'utf8')) : [];
for (const take of takes) {
  take.samples = readWav(path.join(sources, `${take.id}_full_context_dry_v2.wav`));
  const unchanged = previousAlignment.find(previous => previous.id === take.id && previous.source.sha256 === take.source.sha256);
  take.asr = unchanged ? unchanged.asr : await transcriber(resample16(take.samples), { return_timestamps: 'word' });
  console.log(`${take.id}: ${take.asr.text}`);
}
fs.writeFileSync(path.join(evidence, 'voice-v2-source-alignment.json'), JSON.stringify(takes.map(({ samples, ...take }) => take), null, 2) + '\n');
if (process.argv.includes('--sources-only')) { await transcriber.dispose(); process.exit(0); }

function word(text) { return text.toLowerCase().replace(/[^a-z]/g, ''); }
function findWord(take, text, after = 0) {
  const index = take.asr.chunks.findIndex((chunk, i) => i >= after && word(chunk.text) === text);
  if (index < 0) throw new Error(`Alignment missing ${text}; retain old game audio until reviewed`);
  return index;
}
function boundary(take, wordIndex) {
  const expected = take.asr.chunks[wordIndex].timestamp[0];
  const lo = Math.max(0, expected - .42), hi = Math.min(take.samples.length / rate, expected + .20);
  const frame = Math.round(rate * .01), candidates = [];
  let begin = -1;
  for (let at = Math.floor(lo * rate); at < Math.floor(hi * rate); at += frame) {
    let power = 0;
    for (let i = at; i < Math.min(at + frame, take.samples.length); i++) power += take.samples[i] ** 2;
    const quiet = Math.sqrt(power / frame) < .003;
    if (quiet && begin < 0) begin = at;
    if ((!quiet || at + frame >= hi * rate) && begin >= 0) {
      const end = at;
      if (end - begin >= rate * .05) candidates.push({ at: (begin + end) / 2 / rate, quiet_seconds: (end - begin) / rate });
      begin = -1;
    }
  }
  candidates.sort((a, b) => Math.abs(a.at - expected) - Math.abs(b.at - expected));
  if (!candidates.length) throw new Error(`No measured pause near ${take.asr.chunks[wordIndex].text}; refusing to split speech`);
  return { ...candidates[0], word: take.asr.chunks[wordIndex].text, asr_word_start: expected };
}
const mica = takes[0], luke = takes[1], webTake = takes[2];
for (const required of ['home', 'listen', 'keys', 'vault', 'left', 'code', 'plant']) findWord(mica, required);
for (const required of ['these', 'webs', 'yesterday']) findWord(webTake, required);
const micaCuts = [boundary(mica, findWord(mica, 'listen')), boundary(mica, findWord(mica, 'i', findWord(mica, 'vault')))];

function filter(samples, highHz, lowHz) {
  const output = new Float32Array(samples.length);
  const hp = Math.exp(-2 * Math.PI * highHz / rate), lp = 1 - Math.exp(-2 * Math.PI * lowHz / rate);
  let previous = 0, high = 0, low1 = 0, low2 = 0;
  for (let i = 0; i < samples.length; i++) {
    high = hp * (high + samples[i] - previous); previous = samples[i];
    low1 += lp * (high - low1); low2 += lp * (low1 - low2);
    output[i] = low2;
  }
  return output;
}
function master(samples, phone) {
  // Soft voiced peaks, preserved pauses; no artificial breath or pitch warp.
  let output = phone ? filter(samples, 230, 3900) : filter(samples, 65, 10000);
  output = output.map(value => Math.tanh(value * (phone ? 1.6 : 1.25)));
  const measures = stats(output);
  const gain = Math.min(.707 / measures.peak, (phone ? .115 : .105) / measures.rms);
  output = output.map((value, i) => value * gain * Math.min(1, i / (rate * .006), (output.length - i - 1) / (rate * .012)));
  return output;
}
// The full Mica performance is never spliced. Quiet boundaries only change the
// subtitle; Luke's separate game events each have their own complete take.
const micaPerformance = master(mica.samples, true);
const micaSegments = [micaPerformance.slice(0, Math.round(micaCuts[0].at * rate)), micaPerformance.slice(Math.round(micaCuts[0].at * rate), Math.round(micaCuts[1].at * rate)), micaPerformance.slice(Math.round(micaCuts[1].at * rate))];
const reply = master(luke.samples, false);
const web = master(webTake.samples, false);
const voiceCheck = master(takes[3].samples, false);
const isolated = [
  { id: 'mica_complete', samples: micaPerformance, required: ['luke', 'home', 'listen', 'carefully', 'keys', 'vault', 'left', 'code', 'plant'] },
  { id: 'reply', samples: reply, required: [] },
  { id: 'web_reaction', samples: web, required: ['these', 'webs', 'not', 'here', 'yesterday'] },
  { id: 'voice_check', samples: voiceCheck, required: ['can', 'hear', 'voice', 'check'] },
];
for (const line of isolated) {
  line.asr = await transcriber(resample16(line.samples), { return_timestamps: 'word' });
  const words = line.asr.chunks.map(chunk => word(chunk.text));
  if (line.required.some(required => !words.includes(required))) throw new Error(`Processed ${line.id} lost an expected word: ${line.asr.text}`);
  // Tiny Whisper sometimes punctuates the first name as "Micah's"; retain that
  // observation in the report instead of treating its punctuation as speech.
  if (line.id === 'reply' && words.filter(value => /^m[iy][ck](?:a|ah)s?$/.test(value)).length !== 2) throw new Error(`Reply must contain both complete calls to Mica: ${line.asr.text}`);
  console.log(`Verified processed ${line.id}: ${line.asr.text}`);
}
await transcriber.dispose();
fs.writeFileSync(path.join(evidence, 'voice-v2-processed-alignment.json'), JSON.stringify(isolated.map(({ samples, ...line }) => line), null, 2) + '\n');
const tails = [0, 0, .12];
const slots = micaSegments.map((segment, i) => join([segment, silence(tails[i])]));
const warning = join(slots);
// Signal disconnect lands after the entire word plant, without replacing speech.
for (let i = 0; i < rate * .028; i++) warning[warning.length - Math.round(rate * .06) + i] += Math.sin(i * 1.73) * Math.sin(i * .37) * .018 * (1 - i / (rate * .028));
const definitions = [
  ['mica_phone_warning_neural_v2.wav', warning], ['luke_mica_reply_neural_v2.wav', reply],
  ['luke_web_reveal_neural_v4.wav', web], ['luke_voice_check_neural_v2.wav', voiceCheck],
];
const reports = definitions.map(([name, samples]) => report(path.join(generated, name), samples));
const gap = 1.2, replyStart = warning.length / rate + gap;
const metadata = {
  version: 1, caller: 'Mica',
  lines: ["Mica: Luke? It's Mica. You're home.", 'Mica: Listen carefully. The keys are for the vault.', 'Mica: I left the code by the plant—', '[Connection lost]', 'Luke: Mica? ... Mica!'],
  durations: [...slots.map(samples => samples.length / rate), gap, reply.length / rate + .4],
  warning: { ...reports[0], start_seconds: 0 }, reply: { ...reports[1], start_seconds: replyStart },
  web_reaction: { ...reports[2], subtitle: 'Luke: Mica... these webs were not here yesterday.' },
  voice_test: { ...reports[3], subtitle: 'Can you hear me? This is the voice check.' },
  segments: micaSegments.map((samples, i) => ({ id: ['home', 'vault_keys', 'plant_hint'][i], speaker: 'Mica', voice: mica.voice, speed: mica.speed, ...stats(samples), start_seconds: slots.slice(0, i).reduce((sum, slot) => sum + slot.length / rate, 0), subtitle_seconds: slots[i].length / rate })),
  policy: 'The call cuts after the complete word plant. The paper beside the plant outside the vault reveals the code; no code is spoken. Mica remains one continuous waveform; measured quiet intervals only change subtitles. Luke reply and web reaction are separate complete utterances.',
  provenance: { model: modelId, model_source: 'https://huggingface.co/hexgrad/Kokoro-82M', runtime: 'kokoro-js 1.2.1', dtype: 'fp32', voices: [mica.voice, luke.voice], local_inference: true, voice_cloning: false, format: '24 kHz mono PCM16', performance: 'Fresh full-context stock synthetic takes, not a human actor performance; no listening-quality claim', source_takes: takes.map(({ samples, ...take }) => take), measured_boundaries: { mica_subtitles: micaCuts }, processing: 'Mica: 230Hz high-pass and two-pole 3.9kHz low-pass, restrained soft compression and signal disconnect after plant. Luke: low-rumble removal, full-band 10kHz finish. No inserted fake breaths, arbitrary phoneme cuts or pitch shifting.' },
};
const oldMetadata = path.join(project, 'Godot/data/phone_dialogue.json');
const archivedMetadata = path.join(sources, 'phone_dialogue_v1.json');
if (!fs.existsSync(archivedMetadata)) fs.copyFileSync(oldMetadata, archivedMetadata);
fs.writeFileSync(oldMetadata, JSON.stringify(metadata, null, 2) + '\n');
fs.writeFileSync(path.join(evidence, 'mica-dialogue-audio-report-v2.json'), JSON.stringify(metadata, null, 2) + '\n');
const comparison = join([readWav(path.join(generated, 'mica_phone_warning_neural_v1.wav')), silence(1), warning, silence(1), readWav(path.join(generated, 'luke_mica_reply_neural_v1.wav')), silence(1), reply, silence(1), readWav(path.join(generated, 'luke_web_reveal_neural_v3.wav')), silence(1), web]);
report(path.join(evidence, 'voice-v1-v2-comparison.wav'), comparison);
for (const [filename] of definitions) {
  const resource = `res://assets/generated/${filename}`;
  const cache = `res://.godot/imported/${filename}-${createHash('md5').update(resource).digest('hex')}.sample`;
  fs.writeFileSync(path.join(generated, `${filename}.import`), `[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\npath="${cache}"\n\n[deps]\n\nsource_file="${resource}"\ndest_files=["${cache}"]\n\n[params]\n\nforce/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n`);
}
console.log(JSON.stringify({ durations: metadata.durations, warning: metadata.warning, reply: metadata.reply, measured_boundaries: metadata.provenance.measured_boundaries }, null, 2));
