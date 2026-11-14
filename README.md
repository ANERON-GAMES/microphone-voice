# Microphone voice chain

Sets the hardware microphone level and, above 100 percent, a capture-only voice chain.

Playback devices are not processed. Virtual mixers such as Voicemeeter are not selected as the microphone.

## Range

- 10 to 100: level only. 100 is a normal speaking level.
- 101 to 200: RNNoise plus a light peak limiter.
- 201 to 300: stronger RNNoise, a click gate, and a leveler. Quiet speech stays even. Keyboard and mouse clicks are kept out. 300 is the driver loudness cap.

## Install

1. Install Equalizer APO and enable it on the microphone only.
2. Put these 64-bit VST2 plugins in `C:\Program Files\EqualizerAPO\VSTPlugins`:
   - `rnnoise_stereo.dll` from [noise-suppression-for-voice](https://github.com/werman/noise-suppression-for-voice/releases)
   - `LoudMax64.dll` from LoudMax
   - `reagate-standalone.dll` from REAPER ReaPlugs
3. Run `Microphone.bat`.

The plugins are not included. LoudMax and ReaPlugs do not allow redistribution. RNNoise is GPL and is published by its own project.
