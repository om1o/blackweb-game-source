"""Assemble natural-speed intro clips and the accepted 42-second dialogue mix.

Example: python ComposeIntroVideo.py --ffmpeg /path/ffmpeg --clips a.mp4 b.mp4 c.mp4
  --audio /path/town_mix.wav --output /scratch/Blackweb-Luke21-Intro.mp4
  --game-output Godot/assets/generated/cinematics/greyhaven_motion.ogv
Original clips and voice audio remain unmodified. No credentials belong in the ledger.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ffmpeg', required=True, type=Path)
    parser.add_argument('--clips', required=True, nargs='+', type=Path)
    parser.add_argument('--source-ins', nargs='+', type=float,
        help='Explicit source in-points in seconds; preserve natural playback speed')
    parser.add_argument('--source-outs', nargs='+', type=float,
        help='Explicit source out-points in seconds; omit for full source lengths')
    parser.add_argument('--audio', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--game-output', required=True, type=Path)
    parser.add_argument('--ledger', type=Path)
    args = parser.parse_args()
    ffprobe = args.ffmpeg.with_name('ffprobe' + args.ffmpeg.suffix)

    def probe(path):
        return json.loads(subprocess.run([str(ffprobe), '-v', 'error', '-show_streams',
            '-show_format', '-of', 'json', str(path)], check=True, capture_output=True, text=True).stdout)

    def run(arguments, logfile):
        with logfile.open('w', encoding='utf-8') as log:
            subprocess.run([str(args.ffmpeg), '-nostdin', '-hide_banner', '-loglevel', 'warning',
                '-n', *map(str, arguments)], check=True, stdout=log, stderr=subprocess.STDOUT)

    if args.output.exists() or args.game_output.exists():
        raise FileExistsError('Use new output paths; preserve the previous accepted exports.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.game_output.parent.mkdir(parents=True, exist_ok=True)
    clips, start = [], 0.0
    if args.source_ins is not None and len(args.source_ins) != len(args.clips):
        raise ValueError('One source in-point is required per clip.')
    if args.source_outs is not None and len(args.source_outs) != len(args.clips):
        raise ValueError('One source out-point is required per clip.')
    for index, path in enumerate(args.clips):
        details = probe(path)
        video = next(s for s in details['streams'] if s['codec_type'] == 'video')
        source_duration = float(video.get('duration', details['format']['duration']))
        source_in = args.source_ins[index] if args.source_ins else 0.0
        source_out = args.source_outs[index] if args.source_outs else source_duration
        if not (0 <= source_in < source_out <= source_duration + 0.001):
            raise ValueError(f'Invalid trim for {path}: {source_in}..{source_out} of {source_duration}')
        duration = source_out-source_in
        if video['width'] / video['height'] < 1.7:
            raise ValueError('Intro input is not a landscape 16:9 source: ' + str(path))
        clips.append(dict(path=str(path.resolve()), sha256=digest(path), source_in=source_in,
            source_out=source_out, source_duration=source_duration,
            sequence_start=start, sequence_end=start+duration,
            track='picture', audio_owner=False, fit='uniform contain', speed=1.0,
            source_width=video['width'], source_height=video['height']))
        start += duration
    audio_details = probe(args.audio)
    audio_duration = float(audio_details['format']['duration'])
    if abs(start - audio_duration) > 1 / 30 + 0.025:
        raise ValueError(f'Picture {start:.4f}s and accepted audio {audio_duration:.4f}s differ. Edit content; do not stretch or freeze.')
    graph = []
    inputs = []
    for index, clip in enumerate(clips):
        inputs += ['-i', clip['path']]
        graph.append(f'[{index}:v:0]setpts=PTS-STARTPTS,trim=start={clip["source_in"]}:end={clip["source_out"]},'
            f'setpts=PTS-STARTPTS,scale=1280:720:force_original_aspect_ratio=decrease,'
            f'pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p[v{index}]')
    graph.append(''.join(f'[v{i}]' for i in range(len(clips))) +
        f'concat=n={len(clips)}:v=1:a=0,fade=t=in:st=0:d=0.35,fade=t=out:st={start-1:.6f}:d=1[v]')
    inputs += ['-i', str(args.audio)]
    common = [*inputs, '-filter_complex', ';'.join(graph), '-map', '[v]',
        '-map', f'{len(clips)}:a:0', '-ar', '48000', '-ac', '2']
    run([*common, '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-c:a', 'aac',
        '-b:a', '192k', '-movflags', '+faststart', args.output], args.output.with_suffix('.encode.log'))
    # Encode game and review deliveries directly from original sources, avoiding generation loss.
    run([*common, '-c:v', 'libtheora', '-q:v', '6', '-g', '64', '-c:a', 'libvorbis',
        '-q:a', '5', args.game_output], args.output.with_suffix('.game-encode.log'))
    for path in [args.output, args.game_output]:
        with args.output.with_suffix('.decode.log').open('a', encoding='utf-8') as log:
            subprocess.run([str(args.ffmpeg), '-v', 'error', '-i', str(path), '-f', 'null', '-'],
                check=True, stdout=log, stderr=subprocess.STDOUT)
        timing = json.loads(subprocess.run([str(ffprobe), '-v', 'error', '-count_frames',
            '-show_streams', '-of', 'json', str(path)], check=True, capture_output=True, text=True).stdout)
        video = next(s for s in timing['streams'] if s['codec_type'] == 'video')
        audio = next(s for s in timing['streams'] if s['codec_type'] == 'audio')
        expected_frames = round(start*30)
        if int(video['nb_read_frames']) != expected_frames:
            raise ValueError(f'Encoded picture count differs: {path}, expected {expected_frames}')
        for stream in [video, audio]:
            if abs(float(stream['duration'])-start) > 1/30+0.025:
                raise ValueError(f'Encoded stream timing differs: {path}, {stream["codec_type"]}')
    report = dict(schema=1, sequence=dict(width=1280, height=720, fps=30, duration_seconds=start),
        clips=clips, audio=dict(path=str(args.audio.resolve()), sha256=digest(args.audio),
            duration_seconds=audio_duration, speed=1.0, speech='existing accepted Kokoro synthetic recordings'),
        review=dict(path=str(args.output.resolve()), sha256=digest(args.output), probe=probe(args.output)),
        game=dict(path=str(args.game_output.resolve()), sha256=digest(args.game_output), probe=probe(args.game_output)),
        review_status='Encoded and fully decoded; continuous visual/audio review still required')
    ledger = args.ledger or args.output.with_suffix('.edit.json')
    ledger.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(duration_seconds=start, review=str(args.output), game=str(args.game_output), ledger=str(ledger))))


if __name__ == '__main__':
    main()
