import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const scratch=process.env.BLACKWEB_VOICE_SCRATCH||'D:/BlackwebVoiceScratch';
const rate=24000;
const lines={
  records:"Dad's handwriting. He knew what they were doing. Mica brought the evidence here for me.",
  exit_keys:"My keys. She locked them in with the records. She wanted me to find this before I left.",
  containment:"Ordinary spiders, driven up from below. Whatever they made down there is still missing."
};
const {env,pipeline}=await import(pathToFileURL(path.join(scratch,'node_modules/@huggingface/transformers/dist/transformers.node.mjs')));
env.cacheDir=path.join(scratch,'hf-cache');
const {KokoroTTS}=await import(pathToFileURL(path.join(scratch,'node_modules/kokoro-js/dist/kokoro.js')));
const tts=await KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX',{dtype:'fp32',device:'cpu'});
const result={};
const takes=[];
for(const [id,text] of Object.entries(lines)){
  const audio=await tts.generate(text,{voice:'am_michael',speed:.96});
  let samples=audio.audio,first=0,last=samples.length-1;
  while(first<last&&Math.abs(samples[first])<.0015)first++;
  while(last>first&&Math.abs(samples[last])<.0015)last--;
  samples=samples.slice(Math.max(0,first-1680),Math.min(samples.length,last+2400));
  const peak=samples.reduce((a,b)=>Math.max(a,Math.abs(b)),0);
  const gain=Math.min(1.8,.707/peak);
  samples=samples.map((v,i)=>v*gain*Math.min(1,i/144,(samples.length-i-1)/288));
  const b=Buffer.alloc(44+samples.length*2);
  b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(samples.length*2,40);
  samples.forEach((v,i)=>b.writeInt16LE(Math.round(v*32767),44+i*2));
  const resource=`assets/generated/story_${id}.wav`;
  fs.writeFileSync(path.join(root,'Godot',resource),b);
  result[id]={text,path:'res://'+resource,duration_seconds:samples.length/rate,sha256:createHash('sha256').update(b).digest('hex'),voice:'am_michael',engine:'Kokoro-82M fp32 stock synthetic',voice_cloning:false,peak:peak*gain};
  takes.push({id,samples});
  console.log(id,result[id].duration_seconds);
}
await tts.model.dispose();
const transcribe=await pipeline('automatic-speech-recognition','Xenova/whisper-tiny.en',{dtype:'q8',device:'cpu'});
for(const {id,samples} of takes){
  const pcm=Float32Array.from({length:Math.floor(samples.length*2/3)},(_,i)=>samples[Math.floor(i*1.5)]);
  result[id].asr=await transcribe(pcm);
  console.log(id,result[id].asr.text);
}
await transcribe.dispose();
fs.writeFileSync(path.join(root,'Godot/data/story_voice.json'),JSON.stringify(result,null,2)+'\n');
