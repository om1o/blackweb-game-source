# Local dialogue and output checks

`GenerateMicaDialogue.mjs` uses the existing external `D:/BlackwebVoiceScratch` Kokoro cache and packages only the finished WAVs. It generates fictional stock voices (`af_heart`, speed 0.96; `am_michael`, speed 0.92), with no recorded person or voice cloning. Mica has a mild telephone filter; Luke remains full-band. These are synthetic performances, not a claim of human acting or AAA voice production. No subscription, purchase, agreement, or cloud generation is required.

The shared runtime source is `Godot/data/phone_dialogue.json`. Progression reads its five `lines` and `durations`; soundscape reads the audio paths and reply offset. Timings follow complete generated takes, not the previous 11.5-second warning. The warning lasts 6.709 seconds, the disconnect beat 1.2 seconds, and Luke starts at 7.909 seconds. The complete subtitle sequence is 9.770 seconds.

The phone says:

1. Mica: “Luke? It's Mica. You're home.”
2. Mica: “Listen carefully. The keys are for the vault.”
3. Mica: “I left the code by the plant—”
4. [Connection lost]
5. Luke: “Mica? ... Mica!”

The entire word *plant* is retained. A brief signal-break sound follows; neither the speech nor phone subtitles reveal the vault code. Luke's later web reaction is also regenerated with Mica's name.

Run with the installed Node runtime:

```powershell
& 'C:\Program Files\nodejs\node.exe' Tools/Audio/GenerateMicaDialogue.mjs
```

The generator writes deterministic PCM16 import settings before Godot import. It does not guarantee bit-identical neural inference across different ONNX/runtime versions. Keep the four new `.wav.import` sidecars in source control so a clean checkout retains lossless mono PCM16 rather than changing the imported compression. Dependencies and intermediate segments remain outside the distributable game.

## Runtime API

- `Soundscape.play_voice_test() -> bool`: starts the short Luke voice-check sample while paused or inactive, rejects duplicate/active-game requests, and does not consume story flags.
- `Soundscape.stop_voice_test()`: stops the menu sample and releases explicit pauses on story channels. Resume also stops the sample automatically.
- `Soundscape.get_audio_status() -> Dictionary`: driver, output device/list, output latency, bus routing/gain/mute/solo/peaks and stream-load diagnostics. It changes no settings.

All spoken channels use a dedicated `Dialogue` bus feeding `Master`. New bus gain and voice players are 0 dB, removing the former additional −6/−7 dB voice reduction; an existing Dialogue bus's settings are preserved. Phone ambience stays quiet and there is no music. A monotonic wall/playhead clock catches subtitles up after stalled render frames while excluding pauses. A completed warning is explicitly stopped only once its playhead has reached its actual WAV length.

## Verification and limits

`Evidence/mica-dialogue-audio-report.json` records exact generation parameters, hashes, durations and signal statistics. Mica's composed source is −3.01 dBFS peak and −18.86 dBFS RMS; Luke's reply is −3.01 dBFS peak and −19.64 dBFS RMS. Both have zero samples at or above 0.98 amplitude.

`InspectAudioOutput.ps1` reads Windows Core Audio endpoint and application-session gain/mute state; it calls no setter. The recorded observation in `Evidence/mica-audio-windows-mixer.json` found the default endpoint at 78% and unmuted, with the existing game PID19552 at 100% session gain and unmuted. This rules out those observed mute states, but does not identify the user's physical output or prove the user heard it. No OS master volume or device preference was changed.

`Godot/tests/phone_voice_tests.gd` runs the real progression/soundscape with a lightweight subclass of the real player API, using WASAPI and an unmodified `AudioEffectCapture` tap. It checks imported PCM, matching metadata, inactive/menu gating, voice check during pause, duplicate prevention, pause/resume, render stalls during speech and disconnect, late activation, recovery and checkpoint restoration. This is an audio integration fixture, not a full-house human playtest. The native report and verbose teardown log are `Evidence/mica-phone-voice-test-report.json` and `Evidence/mica-phone-voice-native.log`. Only Godot's normal Intel OpenGL-to-ANGLE fallback warning is expected on this machine.

## Primary sources

- [Kokoro model publisher](https://huggingface.co/hexgrad/Kokoro-82M): 82M-parameter model and Apache-2.0 model license.
- [Publisher voice inventory](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md): stock `af_heart` and `am_michael`; quality varies with utterance and voice.
- [Godot audio buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html): routing, gain and bus metering.
- [Godot synchronization guidance](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html): audio mixing occurs in chunks; playback position can be combined with time since mix and output latency, then kept monotonic.
- [Godot AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html): exposes bus samples without changing the signal.
- [Godot AudioServer](https://docs.godotengine.org/en/stable/classes/class_audioserver.html): device, driver, bus and latency diagnostics.

The dialogue wording, cutoff, subtitle schedule, voice-test behavior and game mix are this project's authored design, not claims made by these sources.
