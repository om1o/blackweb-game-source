import {spawnSync} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const scratch=process.env.BLACKWEB_CINEMATIC_SCRATCH||'D:/CodexTemp/Blackweb-TownIntro';
const manifestPath=path.join(root,'Godot/data/town_intro.json');
const previousManifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
if(previousManifest.status==='ready_generated_movie'&&!process.argv.includes('--replace-generated-film'))throw Error('The release uses a reviewed generated film. Pass --replace-generated-film explicitly to replace it with a new 3D source render.');
const ff=process.env.FFMPEG_PATH;
if(!ff)throw Error('Set FFMPEG_PATH to a full FFmpeg build.');
const render=JSON.parse(fs.readFileSync(path.join(scratch,'town-motion.avi.json'),'utf8'));
const hash=file=>createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
if(render.scene_sha256!==hash('Godot/scripts/town_cinematic.gd')||render.voice_envelope_sha256!==hash('Godot/data/town_voice_envelope.json'))throw Error('3D scene or voice timing changed after rendering. Render again before encoding.');
for(const [key,file] of [['character_scene_sha256','Godot/scenes/luke.tscn'],['door_motion_sha256','Godot/assets/generated/cinematics/pinoc_door_samples.json']]){
 if(render[key]!==hash(file))throw Error('Character or PINOC door motion changed after rendering. Render again.');
}
const output=path.join(root,'Godot/assets/generated/cinematics/greyhaven_motion.ogv');
const common=['-y','-hide_banner','-loglevel','warning','-i',path.join(scratch,'town-motion.avi'),'-i',path.join(scratch,'town_mix.wav'),'-map','0:v','-map','1:a','-t','42','-vf','scale=1280:720,setsar=1,fade=t=in:st=0:d=0.8,fade=t=out:st=40.5:d=1.5','-r',String(render.fps)];
for(const [codecs,file] of [[['-c:v','libtheora','-q:v','6','-c:a','libvorbis','-q:a','5'],output],[['-c:v','libx264','-preset','fast','-crf','22','-pix_fmt','yuv420p','-c:a','aac','-movflags','+faststart'],path.join(scratch,'Blackweb-Animated-Intro.mp4')]]){
 const result=spawnSync(ff,[...common,...codecs,file],{stdio:'inherit'});
 if(result.status!==0)throw Error('Encoding failed');
}
if(render.scene_sha256!==hash('Godot/scripts/town_cinematic.gd')||render.voice_envelope_sha256!==hash('Godot/data/town_voice_envelope.json'))throw Error('Sources changed while encoding; do not release this movie.');
const manifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
manifest.status='ready_3d_movie';
manifest.video_path='res://assets/generated/cinematics/greyhaven_motion.ogv';
manifest.medium='Full-motion video rendered from the editable Godot 3D town scene, skinned character animation, authored reactions and voice-envelope jaw motion';
manifest.render_provenance=render;
manifest.render_provenance.video_sha256=hash('Godot/assets/generated/cinematics/greyhaven_motion.ogv');
manifest.delivery.fps=render.fps;
fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+'\n');
console.log('ANIMATED_MOVIE_READY',fs.statSync(output).size);
