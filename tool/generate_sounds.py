#!/usr/bin/env python3
"""Farmelo ses efektlerini sentezler ve assets/sounds/ altına WAV olarak yazar.

Harici kütüphane gerekmez. Sesleri değiştirmek için bu dosyayı düzenleyip çalıştırın:

    python3 tool/generate_sounds.py
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = random.Random(7)


def env(i, n, attack=0.01, release=0.1):
    """Doğrusal atak ve bırakma zarfı (saniye cinsinden)."""
    t = i / RATE
    total = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (total - t) / release) if release > 0 else 1.0
    return max(0.0, min(a, r))


def voice(dur, f0, formants, vib=0.0, vib_rate=5.0, trem=0.0, trem_rate=0.0,
          attack=0.08, release=0.25, harmonics=24, breath=0.0):
    """Harmonik zengin ses + formant ağırlıkları: hayvan sesleri için.

    f0 ve formants, 0..1 arası ilerlemeyi alan fonksiyonlardır.
    """
    n = int(dur * RATE)
    out = []
    phase = 0.0
    lp = 0.0
    for i in range(n):
        p = i / n
        f = f0(p) * (1 + vib * math.sin(2 * math.pi * vib_rate * i / RATE))
        phase += 2 * math.pi * f / RATE
        s = 0.0
        for h in range(1, harmonics + 1):
            hf = h * f
            if hf > RATE / 2:
                break
            w = 0.0
            for fc, bw, gain in formants(p):
                w += gain * math.exp(-((hf - fc) / bw) ** 2)
            s += (w + 0.15 / h) * math.sin(h * phase)
        if breath:
            lp += 0.3 * (rng.uniform(-1, 1) - lp)
            s += breath * lp
        a = env(i, n, attack, release)
        if trem:
            a *= 1 - trem * (0.5 + 0.5 * math.sin(2 * math.pi * trem_rate * i / RATE))
        out.append(s * a)
    return out


def tone(dur, freq, shape="sine", decay=8.0, attack=0.003, sweep_to=None):
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        p = i / n
        f = freq if sweep_to is None else freq + (sweep_to - freq) * p
        phase += 2 * math.pi * f / RATE
        if shape == "sine":
            s = math.sin(phase)
        elif shape == "bell":
            s = math.sin(phase) + 0.35 * math.sin(2 * phase) + 0.15 * math.sin(3 * phase)
        else:  # yumuşak kare
            s = math.sin(phase) + 0.3 * math.sin(3 * phase) + 0.15 * math.sin(5 * phase)
        t = i / RATE
        a = min(1.0, t / attack) * math.exp(-decay * t)
        out.append(s * a)
    return out


def noise(dur, cutoff=0.2, decay=10.0, attack=0.002):
    n = int(dur * RATE)
    out = []
    y = 0.0
    for i in range(n):
        y += cutoff * (rng.uniform(-1, 1) - y)
        t = i / RATE
        out.append(y * min(1.0, t / attack) * math.exp(-decay * t))
    return out


def mix(*tracks):
    """(başlangıç_sn, örnekler, kazanç) üçlülerini üst üste bindirir."""
    length = max(int(start * RATE) + len(s) for start, s, _ in tracks)
    out = [0.0] * length
    for start, s, g in tracks:
        o = int(start * RATE)
        for i, v in enumerate(s):
            out[o + i] += v * g
    return out


def write(name, samples, peak=0.8):
    m = max(1e-9, max(abs(s) for s in samples))
    k = peak / m
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * k * 32767)) for s in samples))
    print(f"{path}  {len(samples) / RATE:.2f} sn")


def lerp(a, b, p):
    return a + (b - a) * p


# ------------------------------------------------------------------ Hayvanlar

def moo(base, dur):
    # "Mmm" ile başlayıp "ööö"ye açılan, alçalan bir böğürme.
    return voice(
        dur,
        f0=lambda p: base * (1.0 + 0.25 * math.sin(math.pi * min(1, p * 1.6)) - 0.2 * p),
        formants=lambda p: [
            (lerp(280, 650, min(1, p * 3)), 160, 1.0),
            (lerp(900, 1100, p), 250, 0.35),
        ],
        vib=0.012, vib_rate=4.5, attack=0.12, release=0.35, breath=0.15,
    )


def baa(base, dur):
    # Hızlı titreşimli "meee".
    return voice(
        dur,
        f0=lambda p: base * (1.08 - 0.12 * p),
        formants=lambda p: [(750, 220, 1.0), (1900, 400, 0.45), (2800, 500, 0.2)],
        vib=0.03, vib_rate=7, trem=0.55, trem_rate=17,
        attack=0.04, release=0.2, breath=0.2,
    )


def cluck():
    parts = []
    for k, (start, f) in enumerate([(0.0, 620), (0.13, 560), (0.24, 540), (0.42, 760)]):
        d = 0.09 if k < 3 else 0.16
        v = voice(
            d,
            f0=lambda p, f=f: f * (1.15 - 0.3 * p),
            formants=lambda p: [(1300, 300, 1.0), (2600, 500, 0.4)],
            attack=0.005, release=0.04, breath=0.5,
        )
        parts.append((start, v, 1.0 if k < 3 else 0.9))
    return mix(*parts)


def peep():
    return mix(
        (0.0, tone(0.09, 2900, decay=12, sweep_to=3500), 1.0),
        (0.14, tone(0.11, 3000, decay=10, sweep_to=3700), 0.9),
    )


# ------------------------------------------------------------------ Efektler

def harvest():
    return mix(
        (0.0, tone(0.12, 380, decay=18, sweep_to=900), 1.0),
        (0.0, noise(0.03, cutoff=0.5, decay=80), 0.4),
        (0.07, tone(0.14, 700, decay=16, sweep_to=1300), 0.7),
    )


def plant():
    return mix(
        (0.0, tone(0.18, 140, decay=18, sweep_to=60), 1.0),
        (0.0, noise(0.12, cutoff=0.08, decay=25), 0.9),
    )


def water():
    parts = [(0.0, noise(0.5, cutoff=0.35, decay=5, attack=0.03), 0.45)]
    for k in range(7):
        f = rng.uniform(900, 1600)
        parts.append((0.03 + k * 0.055 + rng.uniform(0, 0.02),
                      tone(0.06, f, decay=45, sweep_to=f * 1.8), 0.6))
    return mix(*parts)


def coin():
    return mix(
        (0.0, tone(0.09, 988, "bell", decay=20), 0.8),
        (0.07, tone(0.45, 1319, "bell", decay=7), 1.0),
    )


def buy():
    return mix(
        (0.0, noise(0.08, cutoff=0.6, decay=40), 0.35),
        (0.02, tone(0.1, 880, "bell", decay=18), 0.8),
        (0.1, tone(0.4, 1175, "bell", decay=7), 1.0),
    )


def level_up():
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = [(k * 0.1, tone(0.3, f, "square", decay=9), 0.8) for k, f in enumerate(notes)]
    parts.append((0.42, tone(0.9, 1046.5, "bell", decay=3.5), 0.9))
    parts.append((0.42, tone(0.9, 1318.5, "bell", decay=3.5), 0.6))
    return mix(*parts)


def eat():
    return mix(*[(k * 0.11, noise(0.07, cutoff=0.12, decay=35), 1.0) for k in range(3)])


def tap():
    return tone(0.05, 1500, decay=70)


def error():
    return mix(
        (0.0, tone(0.13, 240, "square", decay=12), 1.0),
        (0.14, tone(0.18, 190, "square", decay=10), 1.0),
    )


def main():
    os.makedirs(OUT, exist_ok=True)
    write("moo", moo(135, 1.2))
    write("moo_calf", moo(240, 0.75))
    write("baa", baa(330, 0.8))
    write("baa_lamb", baa(520, 0.55))
    write("cluck", cluck())
    write("peep", peep())
    write("harvest", harvest())
    write("plant", plant())
    write("water", water(), peak=0.6)
    write("coin", coin(), peak=0.6)
    write("buy", buy(), peak=0.6)
    write("level_up", level_up(), peak=0.7)
    write("eat", eat())
    write("tap", tap(), peak=0.4)
    write("error", error(), peak=0.5)


if __name__ == "__main__":
    main()
