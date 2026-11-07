import fs from 'node:fs';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { pathToFileURL, fileURLToPath } from 'node:url';
import path from 'node:path';
// Reuse the separately installed authoring runtime; it is not shipped in-game.
const runtime = process.env.BLACKWEB_VOICE_RUNTIME || 'D:/BlackwebVoiceScratch';
const resolve = createRequire(path.join(runtime,'package.json'));
const { KokoroTTS } = await import(pathToFileURL(resolve.resolve('kokoro-js')).href);
const { env } = await import(pathToFileURL(resolve.resolve('@huggingface/transformers')).href);
env.cacheDir = path.join(runtime,'hf-cache');
env.useBrowserCache = false;
const game = fileURLToPath(new URL('../../Godot/',import.meta.url));
const folder = path.join(game,'assets/generated/boss_voice');
fs.mkdirSync(folder, {recursive:true});
const tts = await KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX', {dtype:'fp32',device:'cpu',session_options:{intraOpNumThreads:2,interOpNumThreads:1}});
const lines = [
 ['arrival','Luke','am_michael',"That thing... it's guarding the greenhouse.",0.93],
 ['greeting','The Smiling Spider','am_adam',"You came back. Good. Stay where I can see you.",0.87],
 ['warning','Mica','af_heart',"Watch its legs, Luke. Move when it commits, then strike.",0.95],
 ['phase_two','The Smiling Spider','am_adam',"No. You don't get to leave.",0.89],
 ['victory','Luke','am_michael',"It's down. I need to move. Now.",0.96]
];
const manifest = {};
for(const [id,speaker,voice,text,speed] of lines){
 const generated = await tts.generate(text,{voice,speed});
 const samples = generated.audio, rate = generated.sampling_rate;
 if(!samples?.length || !rate) throw new Error('Missing generated samples');
 let peak=0,sum=0; for(const v of samples){peak=Math.max(peak,Math.abs(v));sum+=v*v;}
 if(peak<0.01) throw new Error('Silent line: '+id);
 const gain=0.80/peak, bytes=Buffer.alloc(44+samples.length*2);
 bytes.write('RIFF');bytes.writeUInt32LE(bytes.length-8,4);bytes.write('WAVEfmt ',8);
 bytes.writeUInt32LE(16,16);bytes.writeUInt16LE(1,20);bytes.writeUInt16LE(1,22);
 bytes.writeUInt32LE(rate,24);bytes.writeUInt32LE(rate*2,28);bytes.writeUInt16LE(2,32);bytes.writeUInt16LE(16,34);
 bytes.write('data',36);bytes.writeUInt32LE(samples.length*2,40);
 for(let i=0;i<samples.length;i++)bytes.writeInt16LE(Math.round(Math.max(-1,Math.min(1,samples[i]*gain))*32767),44+i*2);
 fs.writeFileSync(folder+'/'+id+'.wav',bytes);
 manifest[id]={speaker,text,path:'res://assets/generated/boss_voice/'+id+'.wav',voice,engine:'Kokoro-82M fp32 stock synthetic voice; no voice cloning',duration:samples.length/rate,peak:0.80,rms:Math.sqrt(sum/samples.length)*gain,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
 console.log(id,manifest[id].duration.toFixed(2));
}
fs.writeFileSync(path.join(game,'data/boss_voice.json'),JSON.stringify(manifest,null,2)+'\n');
