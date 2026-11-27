#!/usr/bin/env python3
"""Write CheckThat's result sounds (#229) to CheckThat/Media/Sounds/*.ogg.

The .ogg files are committed, so the tests and packaging need nothing from here. Run this only to change a sound:
    python3 -m venv /tmp/snd && /tmp/snd/bin/pip install soundfile numpy
    /tmp/snd/bin/python tools/make_sounds.py
Each sound is a few sine notes with a short attack and a decay, 44.1 kHz mono, scaled to one loudness.
"""
import os

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "CheckThat", "Media", "Sounds")

# Note frequencies (equal temperament).
C5, E5, G5, A5, C6, E6, G6 = 523.25, 659.26, 783.99, 880.00, 1046.50, 1318.51, 1567.98

# name: list of (start seconds, frequency, length seconds)
SOUNDS = {
    "tick": [(0.0, E6, 0.07)],                                    # a soft blip: the player recorded a result
    "chime-up": [(0.0, C6, 0.11), (0.09, G6, 0.16)],              # rising: CheckThat recorded a pass
    "chime-down": [(0.0, G5, 0.13), (0.11, C5, 0.2)],             # falling: CheckThat recorded a fail
    "attention": [(0.0, A5, 0.08), (0.15, A5, 0.08)],             # two blips: the step needs the player
    "finish": [(0.0, C6, 0.12), (0.11, E6, 0.12), (0.22, G6, 0.2)],   # arpeggio: the run is complete
}
RMS = 0.08    # the same loudness for every sound
PEAK = 0.5    # and never louder than this


def render(notes):
    import numpy as np
    end = max(s + n for s, _, n in notes) + 0.02
    out = np.zeros(int(end * RATE))
    for start, freq, length in notes:
        t = np.arange(int(length * RATE)) / RATE
        tone = np.sin(2 * np.pi * freq * t) + 0.15 * np.sin(4 * np.pi * freq * t)
        env = np.minimum(1.0, t / 0.005) * np.exp(-t * 5.0 / length)   # 5 ms attack, decay over the note
        i = int(start * RATE)
        out[i:i + len(t)] += tone * env
    out *= RMS / max(np.sqrt(np.mean(out ** 2)), 1e-9)
    peak = np.max(np.abs(out))
    if peak > PEAK:
        out *= PEAK / peak
    return out.astype("float32")


def main():
    import soundfile
    os.makedirs(OUT, exist_ok=True)
    for name, notes in SOUNDS.items():
        path = os.path.join(OUT, name + ".ogg")
        soundfile.write(path, render(notes), RATE, format="OGG", subtype="VORBIS")
        print("%s %d bytes" % (path, os.path.getsize(path)))


if __name__ == "__main__":
    main()
