# Local dialogue and output checks

`GenerateMicaDialogueV2.mjs` uses the external `D:/BlackwebVoiceScratch` Kokoro cache for fresh fp32 synthesis. Mica's complete call is generated as one performance (`af_heart`, speed 0.98); Luke's reply, web reaction and voice check are each complete utterances (`am_michael`, speed 0.96). No recording of a real person or voice cloning is used. The older q8 generator and all older game takes remain available. Neural model/cache files are outside the game project; only small WAV assets and their source takes are packaged.

The shared runtime source is `Godot/data/phone_dialogue.json`. Progression reads its five `lines` and `durations`; soundscape reads the audio paths and reply offset. Exact durations, PCM statistics, SHA-256 hashes, source prompts, voice settings and word-alignment observations are regenerated from the delivered WAVs. The disconnect beat remains 1.2 seconds. Mica's continuous audio is not spliced: measured quiet intervals only change subtitles. Luke's reply and later web reaction use separate complete takes because the bundled draft had no safe intervening silence.

The phone says:

1. Mica: “Luke? It's Mica. You're home.”
2. Mica: “Listen carefully. The keys are for the vault.”
3. Mica: “I left the code by the plant—”
4. [Connection lost]
5. Luke: “Mica? ... Mica!”

The entire word *plant* is retained. A brief signal-break sound follows; neither the speech nor phone subtitles reveal the vault code. Luke's later web reaction is also regenerated with Mica's name.

Run with the installed Node runtime:

```powershell
& 'C:\Program Files\nodejs\node.exe' Tools/Audio/GenerateMicaDialogueV2.mjs
```

The generator writes deterministic PCM16 import settings before Godot import. It does not guarantee bit-identical neural inference across different ONNX/runtime versions. Keep the four new `.wav.import` sidecars in source control so a clean checkout retains lossless mono PCM16 rather than changing the imported compression. `--reuse-takes` reruns alignment and the final mix without neural voice regeneration. Dry source takes and the previous dialogue metadata are retained under `Godot/assets/generated/voice_sources`.

## Runtime API

- `Soundscape.play_voice_test() -> bool`: starts the short Luke voice-check sample while paused or inactive, rejects duplicate/active-game requests, and does not consume story flags.
- `Soundscape.stop_voice_test()`: stops the menu sample and releases explicit pauses on story channels. Resume also stops the sample automatically.
- `Soundscape.get_audio_status() -> Dictionary`: driver, output device/list, output latency, bus routing/gain/mute/solo/peaks and stream-load diagnostics. It changes no settings.

All spoken channels use a dedicated `Dialogue` bus feeding `Master`. New bus gain and voice players are 0 dB, removing the former additional −6/−7 dB voice reduction; an existing Dialogue bus's settings are preserved. Phone ambience stays quiet and there is no music. During speech, a live guard bounds caption time to at most 80 ms ahead of the actual mixer position. It retains the final spoken subtitle until the recording finishes, discards wall-clock overshoot, and preserves the complete disconnect beat before Luke replies. The silent gap still catches up after a stalled render frame. A mixer position that stops advancing for three active seconds is treated as unavailable: the stale channel stops, a diagnostic is recorded, and readable subtitles continue. Missing audio never blocks the deterministic story timeline; game/menu pauses do not consume the fallback timer.

## Verification and limits

`Evidence/mica-dialogue-audio-report-v2.json` records exact generation parameters, hashes, durations and signal statistics. Mica receives a 230 Hz high-pass and two-pole 3.9 kHz low-pass telephone treatment, restrained soft compression, and a brief disconnect after the complete word *plant*. Luke receives low-rumble removal and a wider 10 kHz finish. Peaks are bounded at approximately −3 dBFS; no fake breaths, pitch shifting or arbitrary phoneme cuts are inserted.

Local Whisper tiny.en word alignment checks the dry and finished recordings for all clue words and both calls to Mica. It transcribes the short reply as “Micah's Micah”; that observation is retained, while the authored prompt and subtitles remain “Mica? ... Mica!” Alignment reports are `Evidence/voice-v2-source-alignment.json` and `Evidence/voice-v2-processed-alignment.json`. `Evidence/voice-v1-v2-comparison.wav` alternates old/new Mica, old/new Luke reply and old/new web reaction, with one-second gaps. Waveform and ASR checks establish signal and intelligibility evidence, not subjective acting quality. This agent session cannot listen to audio input; no human-listening review or human-actor quality is claimed.

Higgsfield's Seed Audio quote was checked against the existing 1.7-credit balance. Its tool required a separate stock-voice selection, so the approved local fallback was used. No cloud generation, credit spend, trial activation, subscription, purchase or agreement acceptance occurred.

`InspectAudioOutput.ps1` reads Windows Core Audio endpoint and application-session gain/mute state; it calls no setter. The recorded observation in `Evidence/mica-audio-windows-mixer.json` found the default endpoint at 78% and unmuted, with the existing game PID19552 at 100% session gain and unmuted. This rules out those observed mute states, but does not identify the user's physical output or prove the user heard it. No OS master volume or device preference was changed.

`Godot/tests/phone_voice_tests.gd` runs the real progression/soundscape with a lightweight subclass of the real player API, using WASAPI and an unmodified `AudioEffectCapture` tap. It checks imported PCM, matching metadata, inactive/menu gating, voice check during pause, duplicate prevention, pause/resume, render stalls during speech and disconnect, late activation, recovery, checkpoint restoration, a forced clock leap and a deliberately frozen playback position. That last fault intentionally adds one missing-audio diagnostic to its report. This is an audio integration fixture, not a full-house human playtest. The native report and teardown log are `Evidence/mica-phone-voice-test-report.json` and `Evidence/mica-phone-voice-v2-native.log`. Only Godot's normal Intel OpenGL-to-ANGLE fallback warning is expected on this machine.

## Primary sources

- [Kokoro model publisher](https://huggingface.co/hexgrad/Kokoro-82M): 82M-parameter model and Apache-2.0 model license.
- [Publisher voice inventory](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md): stock `af_heart` and `am_michael`; quality varies with utterance and voice.
- [Official ONNX conversion](https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/tree/main/onnx): the full fp32 model used for these new takes.
- [Transformers.js pipeline API](https://huggingface.co/docs/transformers.js/api/pipelines): local Whisper transcription and word timestamps used as a secondary intelligibility check.
- [Godot audio buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html): routing, gain and bus metering.
- [Godot synchronization guidance](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html): audio mixing occurs in chunks; playback position can be combined with time since mix and output latency, then kept monotonic.
- [Godot AudioEffectCapture](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html): exposes bus samples without changing the signal.
- [Godot AudioServer](https://docs.godotengine.org/en/stable/classes/class_audioserver.html): device, driver, bus and latency diagnostics.
- [Godot AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html): actual playback position, pause, stop and natural completion semantics.

The dialogue wording, cutoff, subtitle schedule, voice-test behavior and game mix are this project's authored design, not claims made by these sources.
