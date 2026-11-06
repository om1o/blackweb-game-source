import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const scratch = process.env.BLACKWEB_VOICE_SCRATCH || 'D:/BlackwebVoiceScratch';
const out = path.join(root, 'Tools/Cinematics/Audio');
const work = process.env.BLACKWEB_CINEMATIC_SCRATCH || 'D:/CodexTemp/Blackweb-TownIntro';
fs.mkdirSync(out, {recursive:true}); fs.mkdirSync(work, {recursive:true});
const rate = 24000, duration = 42;
const takes = [
  {id:'mica_message', voice:'af_heart', at:7, text:'Luke, call me when you get home. Something is wrong.'},
  {id:'luke_town', voice:'am_michael', at:17.2, text:'What happened here?'},
  {id:'luke_road', voice:'am_michael', at:25, text:"The road's blocked. I can get through here."},
  {id:'luke_home', voice:'am_michael', at:33, text:"Mica? I'm home. Are you in there?"},
];
function wav(samples, channels=1) {
  const b=Buffer.alloc(44+samples.length*2);
  b.write('RIFF'); b.writeUInt32LE(b.length-8,4); b.write('WAVEfmt ',8);
  b.writeUInt32LE(16,16); b.writeUInt16LE(1,20); b.writeUInt16LE(channels,22);
  b.writeUInt32LE(rate,24); b.writeUInt32LE(rate*channels*2,28); b.writeUInt16LE(channels*2,32); b.writeUInt16LE(16,34);
  b.write('data',36); b.writeUInt32LE(samples.length*2,40);
  samples.forEach((v,i)=>b.writeInt16LE(Math.round(Math.max(-1,Math.min(1,v))*32767),44+i*2)); return b;
}
const {env}=await import(pathToFileURL(path.join(scratch,'node_modules/@huggingface/transformers/dist/transformers.node.mjs')));
env.cacheDir=path.join(scratch,'hf-cache'); env.useBrowserCache=false;
const {KokoroTTS}=await import(pathToFileURL(path.join(scratch,'node_modules/kokoro-js/dist/kokoro.js')));
const reuse=process.argv.includes('--reuse-voices');
const tts=reuse?null:await KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX',{dtype:'fp32',device:'cpu'});
const mix=new Float32Array(rate*duration*2);
const mouth=new Array(duration*25).fill(0);
let seed=8177, lowL=0, lowR=0;
function noise(){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296*2-1;}
for(let i=0;i<rate*duration;i++){
  const t=i/rate, fade=Math.min(1,t/1.2,(duration-t)/1.2);
  lowL=.96*lowL+.04*noise(); lowR=.96*lowR+.04*noise();
  const engine=0; // Luke arrives on foot; do not imply a moving car.
  const radio=t>13&&t<16?noise()*.012*Math.sin((t-13)*Math.PI/3):0;
  const walking=t<9||(t>=21&&t<31)||(t>=35&&t<41);
  const step=walking?Math.exp(-(t%.534)*32)*Math.sin(2*Math.PI*75*t)*.045:0;
  const latch=t>39.4&&t<39.8?noise()*.05*Math.exp(-(t-39.4)*22):0;
  mix[i*2]=fade*(lowL*.018+engine+radio+step+latch);
  mix[i*2+1]=fade*(lowR*.018+engine+radio*.8+step*.8+latch);
}
for(const take of takes){
  let audio;
  if(reuse){const b=fs.readFileSync(path.join(out,take.id+'.wav'));const a=new Float32Array((b.length-44)/2);for(let i=0;i<a.length;i++)a[i]=b.readInt16LE(44+i*2)/32768;audio={sampling_rate:rate,audio:a};}
  else audio=await tts.generate(take.text,{voice:take.voice,speed:.96});
  if(audio.sampling_rate!==rate)throw Error('Unexpected sample rate');
  let first=0,last=audio.audio.length-1;
  while(first<last&&Math.abs(audio.audio[first])<.0015)first++;
  while(last>first&&Math.abs(audio.audio[last])<.0015)last--;
  const samples=audio.audio.slice(Math.max(0,first-1680),Math.min(audio.audio.length,last+2400));
  let peak=0;for(const v of samples)peak=Math.max(peak,Math.abs(v));
  const gain=.62/Math.max(.01,peak), start=Math.round(take.at*rate);
  if(take.id.startsWith('luke_'))for(let frame=0;frame<Math.ceil(samples.length/(rate/25));frame++){
    let energy=0,count=0;for(let i=frame*(rate/25);i<Math.min(samples.length,(frame+1)*(rate/25));i++){energy+=samples[i]*samples[i];count++;}
    mouth[Math.round(take.at*25)+frame]=Math.min(1,Math.sqrt(energy/Math.max(1,count))*gain*7);
  }
  fs.writeFileSync(path.join(out,take.id+'.wav'),wav(samples));
  for(let i=0;i<samples.length;i++){if((start+i)*2+1>=mix.length)throw Error('Dialogue extends past film');mix[(start+i)*2]+=samples[i]*gain;mix[(start+i)*2+1]+=samples[i]*gain;}
  take.seconds=samples.length/rate; take.end=take.at+take.seconds;
  console.log(take.id+': '+take.seconds.toFixed(3)+'s');
}
if(tts)await tts.model.dispose();
let peak=0,clipped=0; for(const v of mix){peak=Math.max(peak,Math.abs(v));if(Math.abs(v)>=1)clipped++;}
if(clipped)throw Error('Audio mix clipped');
fs.writeFileSync(path.join(work,'town_mix.wav'),wav(mix,2));
fs.writeFileSync(path.join(root,'Godot/data/town_voice_envelope.json'),JSON.stringify({fps:25,samples:mouth})+'\n');
fs.writeFileSync(path.join(out,'provenance.json'),JSON.stringify({model:'onnx-community/Kokoro-82M-v1.0-ONNX',dtype:'fp32',stock_synthetic_voices:true,sample_rate:rate,duration,peak,clipped,takes,ambience:'Original deterministic wind/static noise, walking-timed footsteps and latch synthesis; seed8177; no music'},null,2));
const manifestPath=path.join(root,'Godot/data/town_intro.json');
const manifest=JSON.parse(fs.readFileSync(manifestPath));
for(let i=0;i<takes.length;i++){manifest.captions[i+1].start=takes[i].at;manifest.captions[i+1].end=takes[i].end+.15;manifest.captions[i+1].text=takes[i].text;}
fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+'\n');
console.log('MIX_READY '+path.join(work,'town_mix.wav'));
