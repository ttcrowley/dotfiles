#!/usr/bin/env python3
"""Generates sounds/thock.wav: a soft, low "creamy" keyboard thock + a lighter tock.
Pure stdlib. Edit the knobs below and re-run:  python3 make_thock.py
Output goes to ./sounds/thock.wav (next to this script)."""
import math, os, random, struct, wave

SR = 44100
LENGTH = 0.30            # seconds of audio in the file
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds", "thock.wav")

# ---- knobs ----------------------------------------------------------------
BODY_F0, BODY_F1 = 190.0, 125.0   # main thock pitch sweep (Hz): lower = deeper
BODY_TAU = 0.050                  # body decay (s): longer = rounder / more "creamy"
TOCK_AT = 0.085                   # when the second, lighter tock lands (s)
TOCK_F0, TOCK_F1 = 330.0, 240.0   # tock pitch sweep (Hz)
TOCK_GAIN = 0.55                  # tock loudness relative to the thock
KNOCK_GAIN = 0.30                 # soft knock at the start (bottoming out)
SOFTEN_HZ = 3200.0                # master low-pass: lower = more muffled
PEAK = 0.55                       # final peak level (0..1)
# ---------------------------------------------------------------------------

random.seed(7)  # same noise every run
n = int(SR * LENGTH)
buf = [0.0] * n

def add_tone(t0, f0, f1, tau, gain, sweep=0.040, attack=0.003, harm=0.22):
    start = int(t0 * SR)
    phase = 0.0
    for i in range(start, n):
        t = (i - start) / SR
        f = f1 + (f0 - f1) * math.exp(-t / (sweep / 3.0))   # fast drop, then settles
        phase += 2 * math.pi * f / SR
        env = (1 - math.exp(-t / attack)) * math.exp(-t / tau)
        if env < 1e-5 and t > 0.1:
            break
        buf[i] += gain * env * (math.sin(phase) + harm * math.sin(2 * phase) * math.exp(-t / 0.02))

def add_knock(t0, gain, tau=0.007, cutoff=900.0):
    start = int(t0 * SR)
    a = 1 - math.exp(-2 * math.pi * cutoff / SR)
    y = 0.0
    for i in range(start, min(n, start + int(0.05 * SR))):
        t = (i - start) / SR
        y += a * (random.uniform(-1, 1) - y)                 # one-pole low-pass noise
        buf[i] += gain * math.exp(-t / tau) * (1 - math.exp(-t / 0.0008)) * y * 2.2

add_tone(0.0, BODY_F0, BODY_F1, BODY_TAU, 1.0)
add_knock(0.0, KNOCK_GAIN)
add_tone(TOCK_AT, TOCK_F0, TOCK_F1, BODY_TAU * 0.7, TOCK_GAIN)
add_knock(TOCK_AT, KNOCK_GAIN * 0.5)

# master soften (one-pole low-pass), fade out, normalize
a = 1 - math.exp(-2 * math.pi * SOFTEN_HZ / SR)
y = 0.0
for i in range(n):
    y += a * (buf[i] - y)
    buf[i] = y
fade = int(0.03 * SR)
for i in range(fade):
    buf[n - 1 - i] *= i / fade
m = max(abs(v) for v in buf) or 1.0
buf = [v / m * PEAK for v in buf]

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with wave.open(OUT, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in buf))
print("wrote", OUT)
