"""Original game music loops + sound effects for Master G (pure Python, no
dependencies). Every melody here is composed for this app (no samples, no
copyrighted tunes). Output: 22.05 kHz mono 16-bit WAV, seamless loops.

    python make_music.py OUT_DIR
"""
import math
import random
import struct
import sys
import wave
from array import array

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
TAU = 2 * math.pi


# ------------------------------------------------------------------ helpers
def buf(seconds):
    return array('f', bytes(4 * int(seconds * SR)))


def note_hz(n):
    """MIDI note number → Hz (69 = A4)."""
    return 440.0 * 2 ** ((n - 69) / 12)


def env_adsr(i, n, a, d, s, r):
    t = i / SR
    dur = n / SR
    if t < a:
        return t / a
    if t < a + d:
        return 1 - (1 - s) * (t - a) / d
    if t > dur - r:
        return s * max(0.0, (dur - t) / r)
    return s


def add(b, start, samples, gain=1.0):
    s = int(start * SR)
    for k, v in enumerate(samples):
        j = s + k
        if j >= len(b):
            j -= len(b)  # wrap for seamless loops
        b[j] += v * gain


def osc(kind, ph):
    x = ph % 1.0
    if kind == 'sine':
        return math.sin(TAU * x)
    if kind == 'square':
        return 1.0 if x < 0.5 else -1.0
    if kind == 'pulse':
        return 1.0 if x < 0.25 else -1.0
    if kind == 'saw':
        return 2 * x - 1
    if kind == 'tri':
        return 4 * abs(x - 0.5) - 1
    return 0.0


def voice(freq, dur, kind='sine', adsr=(0.01, 0.1, 0.7, 0.1), vib=0.0, detune=0.0, bright=0.0):
    n = int(dur * SR)
    out = [0.0] * n
    ph = ph2 = 0.0
    lp = 0.0
    for i in range(n):
        f = freq * (1 + vib * math.sin(TAU * 5.5 * i / SR))
        ph += f / SR
        v = osc(kind, ph)
        if detune:
            ph2 += f * (1 + detune) / SR
            v = 0.5 * (v + osc(kind, ph2))
        # Simple one-pole low-pass to tame harsh waves (bright 0..1).
        k = 0.08 + 0.9 * bright
        lp += k * (v - lp)
        out[i] = lp * env_adsr(i, n, *adsr)
    return out


def pluck(freq, dur, bright=0.5, bend=0.0):
    """Karplus-Strong string (sitar / guitar-like pluck)."""
    n = int(dur * SR)
    period = max(2, int(SR / freq))
    rnd = random.Random(int(freq * 100))
    line = [rnd.uniform(-1, 1) for _ in range(period)]
    out = [0.0] * n
    idx = 0
    for i in range(n):
        a = line[idx]
        b = line[(idx + 1) % period]
        nv = (a * (1 - bright * 0.5) + b * (bright * 0.5 + 0.5)) * 0.996
        line[idx] = nv
        out[i] = a
        idx = (idx + 1) % period
        if bend and i % 220 == 0 and period > 3 and i < n * 0.3:
            pass  # (kept simple: no pitch bend in the delay line)
    return out


def bell(freq, dur):
    n = int(dur * SR)
    parts = [(1.0, 1.0), (2.76, 0.45), (5.4, 0.25), (8.93, 0.12)]
    return [sum(a * math.sin(TAU * freq * m * i / SR) * math.exp(-i / SR * (2.2 + m * 0.6)) for m, a in parts) * 0.5
            for i in range(n)]


def kick(dur=0.35):
    n = int(dur * SR)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        f = 45 + 110 * math.exp(-t * 28)
        ph += f / SR
        out.append(math.sin(TAU * ph) * math.exp(-t * 9))
    return out


def snare(dur=0.2, tone=190, seed=1):
    rnd = random.Random(seed)
    n = int(dur * SR)
    lp = 0.0
    out = []
    for i in range(n):
        t = i / SR
        nz = rnd.uniform(-1, 1)
        lp += 0.6 * (nz - lp)
        out.append((0.75 * (nz - lp) + 0.35 * math.sin(TAU * tone * t)) * math.exp(-t * 18))
    return out


def hat(dur=0.05, seed=2):
    rnd = random.Random(seed)
    n = int(dur * SR)
    prev = 0.0
    out = []
    for i in range(n):
        nz = rnd.uniform(-1, 1)
        out.append((nz - prev) * math.exp(-i / SR * 70))
        prev = nz
    return out


def tabla(kind, seed=3):
    """'dha' (bass + slap), 'na' (ringing high), 'ge' (bass bend)."""
    n = int(0.45 * SR)
    out = []
    ph1 = ph2 = 0.0
    rnd = random.Random(seed)
    for i in range(n):
        t = i / SR
        hi = 0.0
        if kind in ('na', 'dha'):
            ph2 += 520 / SR
            hi = math.sin(TAU * ph2) * math.exp(-t * 11) * 0.7 + rnd.uniform(-1, 1) * math.exp(-t * 90) * 0.3
        lo = 0.0
        if kind in ('ge', 'dha'):
            f = 95 + 60 * math.exp(-t * 6)
            ph1 += f / SR
            lo = math.sin(TAU * ph1) * math.exp(-t * 4.5)
        out.append(hi + lo)
    return out


def save(name, b, gain_db=-1.0):
    peak = max(1e-6, max(abs(v) for v in b))
    g = 10 ** (gain_db / 20) / peak
    with wave.open(f'{OUT}/{name}.wav', 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, v * g)) * 32767)) for v in b))
    print('wrote', name, f'{len(b) / SR:.1f}s')


# Chord helpers (MIDI root, quality)
def chord(root, q):
    return [root + x for x in {'maj': (0, 4, 7), 'min': (0, 3, 7), 'maj7': (0, 4, 7, 11), 'min7': (0, 3, 7, 10), 'dom7': (0, 4, 7, 10)}[q]]


# ------------------------------------------------------------------ tracks
def arcade_groove():
    """Upbeat chiptune for the Arcade / default home (120 BPM, 16 bars)."""
    bpm, bars = 120, 16
    beat = 60 / bpm
    b = buf(bars * 4 * beat)
    prog = [(60, 'maj'), (67, 'maj'), (69, 'min'), (65, 'maj')]  # C G Am F
    melody = [72, 76, 79, 76, 74, 71, 74, 79, 76, 72, 69, 72, 77, 76, 74, 72]
    for bar in range(bars):
        root, q = prog[bar % 4]
        t0 = bar * 4 * beat
        for k in range(8):  # bass eighths
            n = root - 24 + (12 if k % 2 else 0)
            add(b, t0 + k * beat / 2, voice(note_hz(n), beat / 2 * 0.9, 'tri', (0.005, 0.05, 0.8, 0.03)), 0.5)
        for k in range(4):  # arpeggio
            n = chord(root, q)[k % 3] + 12
            add(b, t0 + k * beat + beat / 2, voice(note_hz(n), beat * 0.3, 'pulse', (0.002, 0.05, 0.4, 0.05), bright=0.4), 0.12)
        if bar >= 4:  # lead after the intro
            for k in range(4):
                n = melody[(bar * 4 + k) % len(melody)] + (0 if bar < 12 else 12)
                add(b, t0 + k * beat, voice(note_hz(n), beat * 0.85, 'square', (0.005, 0.08, 0.6, 0.08), vib=0.004, bright=0.35), 0.16)
        for k in range(4):  # drums
            add(b, t0 + k * beat, kick(), 0.6 if k % 2 == 0 else 0.35)
            if k % 2 == 1:
                add(b, t0 + k * beat, snare(), 0.35)
            add(b, t0 + k * beat + beat / 2, hat(), 0.18)
    save('music_arcade', b)


def desi_festive():
    """Festive Indian groove: tanpura drone, plucked 'sitar' in raag Khamaj,
    tabla theka (100 BPM, 12 bars)."""
    bpm, bars = 100, 12
    beat = 60 / bpm
    b = buf(bars * 4 * beat)
    sa = 62  # D
    scale = [0, 2, 4, 5, 7, 9, 10, 12]  # Khamaj (komal ni)
    rnd = random.Random(7)
    # Drone (Sa + Pa) through the whole loop.
    total = bars * 4 * beat
    for nn, g in ((sa - 24, 0.12), (sa - 17, 0.08), (sa - 12, 0.07)):
        add(b, 0, voice(note_hz(nn), total, 'saw', (0.5, 0.1, 0.9, 0.5), detune=0.003, bright=0.05), g)
    phrase = [0, 2, 4, 5, 4, 2, 4, 7, 5, 4, 2, 0, 2, 4, 2, 0]
    for bar in range(bars):
        t0 = bar * 4 * beat
        theka = ['dha', 'dha', 'na', 'dha', 'dha', 'na', 'ge', 'na']
        for k, bol in enumerate(theka):
            add(b, t0 + k * beat / 2, tabla(bol, seed=bar * 8 + k), 0.45 if bol != 'na' else 0.3)
        if bar >= 2:
            for k in range(4):
                deg = phrase[(bar * 4 + k) % len(phrase)]
                if rnd.random() < 0.15:
                    continue
                n = sa + 12 + scale[deg % len(scale)]
                add(b, t0 + k * beat, pluck(note_hz(n), beat * 1.6, bright=0.8), 0.5)
                if k % 2 == 1 and rnd.random() < 0.5:  # quick grace note
                    add(b, t0 + k * beat + beat / 2, pluck(note_hz(n + 2), beat * 0.6, bright=0.8), 0.3)
    save('music_festive', b)


def calm_lofi():
    """Soft lo-fi for Mom Memory / calm screens (72 BPM, 8 bars)."""
    bpm, bars = 72, 8
    beat = 60 / bpm
    b = buf(bars * 4 * beat)
    prog = [(60, 'maj7'), (57, 'min7'), (62, 'min7'), (55, 'dom7')]
    for bar in range(bars):
        root, q = prog[bar % 4]
        t0 = bar * 4 * beat
        for n in chord(root, q):  # electric-piano chord
            add(b, t0, voice(note_hz(n), 4 * beat * 0.95, 'sine', (0.02, 0.6, 0.5, 0.6), vib=0.002), 0.13)
            add(b, t0, voice(note_hz(n + 12), 4 * beat * 0.6, 'sine', (0.01, 0.3, 0.2, 0.3)), 0.04)
        add(b, t0, voice(note_hz(root - 12), 2 * beat, 'tri', (0.02, 0.2, 0.6, 0.3), bright=0.1), 0.28)
        add(b, t0 + 2.5 * beat, voice(note_hz(root - 12), 1.5 * beat, 'tri', (0.02, 0.2, 0.6, 0.3), bright=0.1), 0.22)
        for k in range(4):
            add(b, t0 + k * beat, kick(0.3), 0.32 if k in (0, 2) else 0.0)
            if k in (1, 3):
                add(b, t0 + k * beat, snare(0.18, seed=k), 0.16)
            for h in (0, 0.5):
                add(b, t0 + (k + h + 0.04) * beat, hat(0.04, seed=k), 0.07)
    # Vinyl crackle.
    rnd = random.Random(9)
    for i in range(0, len(b), 37):
        if rnd.random() < 0.08:
            b[i] += rnd.uniform(-0.12, 0.12)
    save('music_lofi', b)


def neon_synthwave():
    """Neon Night: driving synthwave (108 BPM, 16 bars)."""
    bpm, bars = 108, 16
    beat = 60 / bpm
    b = buf(bars * 4 * beat)
    prog = [(57, 'min'), (53, 'maj'), (60, 'maj'), (55, 'maj')]  # Am F C G
    lead = [76, 74, 72, 74, 76, 79, 76, 74]
    for bar in range(bars):
        root, q = prog[bar % 4]
        t0 = bar * 4 * beat
        for k in range(16):  # rolling 16th bass
            n = root - 24 + (12 if k % 4 == 2 else 0)
            add(b, t0 + k * beat / 4, voice(note_hz(n), beat / 4 * 0.85, 'saw', (0.003, 0.05, 0.5, 0.02), bright=0.25), 0.22)
        for n in chord(root, q):  # pad
            add(b, t0, voice(note_hz(n), 4 * beat, 'saw', (0.4, 0.3, 0.7, 0.4), detune=0.006, bright=0.06), 0.07)
        if bar >= 8:
            for k in range(2):
                n = lead[(bar * 2 + k) % len(lead)]
                add(b, t0 + k * 2 * beat, voice(note_hz(n), 2 * beat * 0.9, 'saw', (0.01, 0.2, 0.7, 0.3), vib=0.006, detune=0.004, bright=0.3), 0.12)
        for k in range(4):
            add(b, t0 + k * beat, kick(), 0.6)
            if k % 2 == 1:
                add(b, t0 + k * beat, snare(0.28, tone=170, seed=bar), 0.42)
            add(b, t0 + k * beat + beat / 2, hat(), 0.15)
    save('music_neon', b)


def winter_bells():
    """Winter / Christmas: original bell melody, sleigh shakers (96 BPM, 8 bars)."""
    bpm, bars = 96, 8
    beat = 60 / bpm
    b = buf(bars * 4 * beat)
    prog = [(65, 'maj'), (62, 'min'), (70, 'maj'), (72, 'maj')]  # F Dm Bb C
    tune = [77, 81, 84, 81, 79, 77, 74, 77, 79, 81, 79, 77, 76, 77, 79, 72]
    for bar in range(bars):
        root, q = prog[bar % 4]
        t0 = bar * 4 * beat
        for n in chord(root, q):
            add(b, t0, voice(note_hz(n), 4 * beat, 'tri', (0.2, 0.4, 0.6, 0.4), bright=0.05), 0.08)
        add(b, t0, voice(note_hz(root - 12), 4 * beat * 0.9, 'sine', (0.02, 0.3, 0.6, 0.3)), 0.25)
        for k in range(2):
            n = tune[(bar * 2 + k) % len(tune)]
            add(b, t0 + k * 2 * beat, bell(note_hz(n), 2 * beat), 0.32)
            add(b, t0 + k * 2 * beat + beat, bell(note_hz(n + 7), beat), 0.14)
        for k in range(8):  # sleigh bells
            add(b, t0 + k * beat / 2, hat(0.09, seed=k + bar), 0.13 if k % 2 else 0.2)
        add(b, t0, kick(0.3), 0.3)
        add(b, t0 + 2 * beat, kick(0.3), 0.25)
    save('music_winter', b)


# ------------------------------------------------------------------ effects
def sfx():
    def mixl(*parts, offs=None):
        offs = offs or [0] * len(parts)
        n = max(int(o * SR) + len(p) for p, o in zip(parts, offs))
        out = array('f', bytes(4 * n))
        for p, o in zip(parts, offs):
            s = int(o * SR)
            for i, v in enumerate(p):
                out[s + i] += v
        return out

    C5, E5, G5, C6, E6, G6 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0
    # Level up: rising arpeggio + shimmer.
    save('sfx_levelup', mixl(*[voice(f, 0.18, 'square', (0.003, 0.05, 0.6, 0.1), bright=0.4) for f in (C5, E5, G5, C6, E6)],
                             bell(G6, 0.6), offs=[0, 0.07, 0.14, 0.21, 0.28, 0.32]))
    # Combo: quick upward blips.
    save('sfx_combo', mixl(*[voice(f, 0.07, 'pulse', (0.002, 0.03, 0.6, 0.03), bright=0.5) for f in (880, 1175, 1568)], offs=[0, 0.05, 0.1]))
    # Unlock: chime + sparkle.
    save('sfx_unlock', mixl(bell(1046.5, 0.8), bell(1568, 0.7), hat(0.25, seed=5), offs=[0, 0.09, 0.05]))
    # Countdown tick.
    save('sfx_tick', mixl(voice(1600, 0.03, 'sine', (0.001, 0.01, 0.4, 0.02)), hat(0.02)))
    # Buzzer (wrong / time up).
    save('sfx_buzzer', mixl(voice(150, 0.45, 'square', (0.005, 0.05, 0.8, 0.1), vib=0.02, bright=0.3), voice(155, 0.45, 'saw', (0.005, 0.05, 0.8, 0.1), bright=0.3)))
    # Celebration: fanfare + clap-like noise bursts.
    fan = [voice(f, 0.16 if i < 3 else 0.6, 'square', (0.005, 0.05, 0.7, 0.1), bright=0.35) for i, f in enumerate((G5, G5, G5, C6))]
    claps = [snare(0.12, tone=900, seed=i) for i in range(4)]
    save('sfx_celebrate', mixl(*fan, *claps, bell(E6, 0.9), offs=[0, 0.13, 0.26, 0.4, 0.4, 0.55, 0.7, 0.85, 0.45]))
    # Soft button.
    save('sfx_button', mixl(voice(700, 0.05, 'sine', (0.001, 0.02, 0.3, 0.02)), voice(1050, 0.04, 'sine', (0.001, 0.02, 0.2, 0.02)), offs=[0, 0.01]))
    # Card flip (paper flick).
    save('sfx_cardflip', mixl(snare(0.07, tone=2400, seed=11), voice(900, 0.04, 'tri', (0.001, 0.02, 0.2, 0.02)), offs=[0, 0.01]))
    # Coin shower (big reward).
    save('sfx_coins', mixl(*[bell(1800 + (i % 3) * 400, 0.35) for i in range(7)], offs=[i * 0.06 for i in range(7)]))
    # Swoosh up (menu / screen change).
    rnd = random.Random(4)
    n = int(0.3 * SR)
    lp = 0.0
    sw = []
    for i in range(n):
        k = 0.02 + 0.5 * i / n
        lp += k * (rnd.uniform(-1, 1) - lp)
        sw.append(lp * math.sin(math.pi * i / n))
    save('sfx_swoosh', mixl(sw))


if __name__ == '__main__':
    random.seed(1)
    arcade_groove()
    desi_festive()
    calm_lofi()
    neon_synthwave()
    winter_bells()
    sfx()
