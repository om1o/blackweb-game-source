# Mara warning and Luke reply

The phone interaction now plays Mara's incomplete warning, then Luke's answer. Dialogue stays short and retains the existing mystery about Greyhaven. There is no added music or exposition.

| Subtitle start | Speaker | Exact spoken words | Generated speech length |
| ---: | --- | --- | ---: |
| 0.0 s | Mara | Luke? If you get this, stay home. | 1.846 s |
| 3.5 s | Mara | Something's happening in Greyhaven. The streets are— | 2.972 s |
| 7.5 s | Mara | Don't come looking for me. Please. I can hear— | 2.791 s |
| 11.5 s | — | [Connection lost] (subtitle only) | 2.0 s beat |
| 13.5 s | Luke | Mara. Pick up. ...I'm coming. | 2.078 s |

`Tools/Audio/GenerateMaraWarning.mjs` generated fictional synthetic speech locally with [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M), the [ONNX conversion](https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX), and [kokoro-js](https://github.com/hexgrad/kokoro/tree/main/kokoro.js) 1.2.1. These identify Apache-2.0 licensing. Mara uses the stock American female `af_heart` voice at 0.96 speed; Luke uses the existing `am_michael` voice at 0.92. No human recording, voice cloning, impersonation, or paid speech service was used. The dependency/model cache remains outside the game at `D:/BlackwebVoiceScratch`; `BLACKWEB_VOICE_SCRATCH` can override that location when rerunning the tool.

The generator trims only quiet lead/tail samples, applies a gentle 150–3700 Hz phone filter to Mara, aligns her three lines to the existing subtitle slots, and adds a quiet 35 ms signal break. It does not crop spoken words or increase speed to force a fit. Luke's reply is a separate file without the phone filter. Both files are 24 kHz mono PCM16 with a 0.75 peak (−2.50 dBFS) and zero samples above 0.98. Import settings retain PCM16 rather than applying Godot's default lossy voice compression. Source signal measurements and exact text are in `Evidence/mara-warning-audio-report.json`.

| File under `Godot/assets/generated` | Bytes | Duration | SHA-256 |
| --- | ---: | ---: | --- |
| `mara_phone_warning_neural_v1.wav` | 552,044 | 11.500 s | `9a9623688400ab9cd2ecdf71c2923333a0e306dad9709cf8928d3f8f7093f949` |
| `luke_phone_reply_neural_v1.wav` | 99,778 | 2.078 s | `12592e9c5170186b487df8abf8cfd4870f1a645142fd550e01221044f341e891` |

`soundscape.gd` starts speech only during active MESSAGE play, seeks to the current subtitle time after late activation, rejects duplicate starts, stops Mara at the connection-loss boundary, and waits until 13.5 seconds for Luke. A monotonic wall/audio clock catches the existing subtitle timer up after a long frame, including the silent connection-loss beat, without seeking backward or replaying a stage. Pause time is excluded. The mixer position accounts for the last mix and output latency using Godot's [audio synchronization guidance](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html). Pause/recovery/departure stop or suspend narration appropriately; restoring a MESSAGE checkpoint permits one synchronized fresh attempt. The later web reaction is blocked until PREPARATION, so Luke cannot speak over the phone sequence. No `main.gd` or progression dialogue/timing edits were needed.

The two generated WAV import sidecars retain `compress/mode=0` in source control. `node Tools/Audio/GenerateMaraWarning.mjs --imports-only` reapplies that setting without loading Kokoro or regenerating speech; run Godot's editor import afterward if it changed. A new audio file without an import sidecar must first be imported once in Godot. The generator refuses unexpected sidecar formats rather than silently changing other audio imports.

Native verification on 2026-11-04 passed all **24** event/timing checks in `Godot/tests/phone_voice_tests.gd`, including a 400 ms blocked frame during speech and a 350 ms stall during the silent gap, pause, late activation, recovery, checkpoint restore and duplicate starts. Second/third-line audio offsets were 24/23 ms. Run this test without `--headless`: Godot's Dummy audio driver can lag under load and cannot establish hardware audio synchronization. The report is `Evidence/phone-voice-test-report.json`.

The actual house capture also passed **3/3** with matching visible captions, speech playing and the web reaction blocked. Audio/subtitle differences measured before PNG readback were 24, 68 and 36 ms, below the 250 ms test bound. `Godot/tools/capture_phone_warning.gd` writes `Evidence/phone-voice-native-capture.json` and the three `mara-warning-*-native.png` / `luke-phone-reply-native.png` captures. Both native test processes exited successfully.

This is a synthetic voice pass, not a final actor performance. Signal and event verification can establish clean files and correct timing; they do not establish acting quality. Local WAV previews are available for a listening review.
