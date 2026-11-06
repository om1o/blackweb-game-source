import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const scratch=process.env.BLACKWEB_VOICE_SCRATCH || 'D:/BlackwebVoiceScratch';
const {env,pipeline}=await import(pathToFileURL(path.join(scratch,'node_modules/@huggingface/transformers/dist/transformers.node.mjs')));
env.cacheDir=path.join(scratch,'hf-cache');
const transcribe=await pipeline('automatic-speech-recognition','Xenova/whisper-tiny.en',{dtype:'q8',device:'cpu'});
const provenance=JSON.parse(fs.readFileSync(path.join(here,'Audio/provenance.json'),'utf8'));
const results=[];
for(const take of provenance.takes){
 const wav=fs.readFileSync(path.join(here,'Audio',`${take.id}.wav`));
 const samples=new Float32Array(Math.floor((wav.length-44)/2/1.5));
 for(let i=0;i<samples.length;i++){const at=i*1.5,lo=Math.floor(at),f=at-lo; samples[i]=(wav.readInt16LE(44+lo*2)*(1-f)+wav.readInt16LE(44+Math.min(lo+1,(wav.length-44)/2-1)*2)*f)/32768;}
 const result=await transcribe(samples);
 results.push({id:take.id,expected:take.text,recognized:result.text});
 console.log(take.id,result.text);
}
await transcribe.dispose();
fs.writeFileSync(path.join(here,'Audio/transcription-review.json'),JSON.stringify(results,null,2)+'\n');
