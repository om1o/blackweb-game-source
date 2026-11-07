"""Extract 25 Hz RMS envelopes for the existing stock boss dialogue recordings."""
from pathlib import Path
import wave,array,math,json
r=Path(__file__).resolve().parents[2];result={}
for name in ['greeting','phase_two']:
    with wave.open(str(r/'Godot/assets/generated/boss_voice'/f'{name}.wav'),'rb') as f:
        assert f.getsampwidth()==2 and f.getnchannels()==1
        rate=f.getframerate();samples=array.array('h',f.readframes(f.getnframes()))
    step=round(rate/25);values=[]
    for i in range(0,len(samples),step):
        chunk=samples[i:i+step];rms=math.sqrt(sum((v/32768)**2 for v in chunk)/len(chunk))
        values.append(round(min(1,rms*4.5),4))
    result[name]={'fps':25,'samples':values}
(r/'Godot/data/boss_voice_envelopes.json').write_text(json.dumps(result,separators=(',',':')))
