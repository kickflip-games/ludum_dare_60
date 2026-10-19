"""Bake the original quiet filtered-noise surf into a seamless 32 s PCM loop.

Standard library only, deterministic. The overlap is equal-power to retain the
noise floor. Runtime weather/speed gain remains in crossing.gd.
"""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
LENGTH = RATE * 32
OVERLAP = RATE * 2
rng = random.Random(60)
noise = 0.0
samples = []
for i in range(LENGTH + OVERLAP):
    t = i / RATE
    noise += (rng.uniform(-1, 1) - noise) * 0.07
    samples.append(noise * (0.45 + 0.2 * math.sin(t * 0.75))
                   + math.sin(t * math.tau * 57) * 0.015)
# Start in the overlap and finish on the sample immediately before its next frame.
loop = samples[OVERLAP: LENGTH]
for i in range(OVERLAP):
    fraction = i / (OVERLAP - 1)
    a, b = math.cos(fraction * math.pi / 2), math.sin(fraction * math.pi / 2)
    loop.append(samples[LENGTH + i] * a + samples[i] * b)
output = Path(__file__).resolve().parents[1] / 'ldjam_60/assets/sounds/ocean_loop.wav'
output.parent.mkdir(exist_ok=True)
with wave.open(str(output), 'wb') as wav:
    wav.setparams((1, 2, RATE, LENGTH, 'NONE', 'not compressed'))
    wav.writeframes(b''.join(struct.pack('<h', round(max(-1, min(1, s)) * 32767)) for s in loop))
print(output)
