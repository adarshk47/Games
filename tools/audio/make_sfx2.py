"""Second sound-effect set for Master G: soft, rounded "premium" sounds
(marimba / glass / soft bell, light room reverb). Pure Python, original.

    python make_sfx2.py OUT_DIR

Writes one WAV per Sound enum value (tap.wav, pop.wav, ... swoosh.wav).
"""
import math
import random
import struct
import sys
import wave

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
TAU = 2 * math.pi


def n_of(sec):
    return int(sec * SR)


def mix(parts):
    """parts: list of (start_sec, samples, gain)."""
    n = max(n_of(s) + len(p) for s, p, _ in parts)
    out = [0.0] * n
    for s, p, g in parts:
        o = n_of(s)
        for i, v in enumerate(p):
            out[o + i] += v * g
    return out


def marimba(f, dur=0.35, hard=0.5):
    """Struck bar: fundamental + 4x partial that dies fast, soft attack."""
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        a = min(1.0, t / 0.002)
        v = math.sin(TAU * f * t) * math.exp(-t * 9)
        v += hard * 0.5 * math.sin(TAU * f * 3.98 * t) * math.exp(-t * 40)
        v += 0.15 * math.sin(TAU * f * 9.9 * t) * math.exp(-t * 90) * hard
        out.append(a * v)
    return out


def glass(f, dur=0.6):
    """Soft glass / celesta tone."""
    parts = [(1.0, 1.0, 4.0), (2.0, 0.35, 6.0), (3.01, 0.18, 9.0), (5.04, 0.08, 14.0)]
    out = []
    for i in range(n_of(dur)):
        t = i / SR
        a = min(1.0, t / 0.004)
        out.append(a * sum(g * math.sin(TAU * f * m * t) * math.exp(-t * d) for m, g, d in parts) * 0.6)
    return out


def soft(f, dur, kind='sine', att=0.01, rel=0.08, f_end=None, vib=0.0):
    """Sine/triangle voice with optional glide (f -> f_end)."""
    n = n_of(dur)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ff = f if f_end is None else f * (f_end / f) ** (i / n)
        ff *= 1 + vib * math.sin(TAU * 6 * t)
        ph += ff / SR
        x = ph % 1.0
        v = math.sin(TAU * x) if kind == 'sine' else (4 * abs(x - 0.5) - 1)
        e = min(1.0, t / att) * min(1.0, (dur - t) / rel)
        out.append(v * max(0.0, e))
    return out


def noise(dur, lp_from=0.05, lp_to=0.05, seed=1, decay=0.0, shape='sin'):
    rnd = random.Random(seed)
    n = n_of(dur)
    out, lp = [], 0.0
    for i in range(n):
        k = lp_from + (lp_to - lp_from) * i / n
        lp += k * (rnd.uniform(-1, 1) - lp)
        env = math.sin(math.pi * i / n) if shape == 'sin' else math.exp(-i / SR * decay)
        out.append(lp * env)
    return out


def reverb(x, wet=0.18, room=0.08):
    """Tiny Schroeder-style room (3 combs + 1 allpass), adds a tail."""
    tail = n_of(0.35)
    y = x + [0.0] * tail
    out = [0.0] * len(y)
    for d, fb in ((n_of(room * 0.37), 0.55), (n_of(room * 0.43), 0.5), (n_of(room * 0.53), 0.45)):
        buf = [0.0] * len(y)
        for i in range(len(y)):
            buf[i] = y[i] + (fb * buf[i - d] if i >= d else 0.0)
            out[i] += buf[i] / 3
    d, g = n_of(0.005), 0.5
    ap = [0.0] * len(out)
    for i in range(len(out)):
        prev = ap[i - d] if i >= d else 0.0
        xin = out[i - d] if i >= d else 0.0
        ap[i] = -g * out[i] + xin + g * prev
    res = [y[i] * (1 - wet) + ap[i] * wet for i in range(len(y))]
    # Trim silent tail.
    end = len(res)
    while end > 1 and abs(res[end - 1]) < 1e-4:
        end -= 1
    return res[:end]


def save(name, b, peak_db=-3.0):
    peak = max(1e-6, max(abs(v) for v in b))
    g = 10 ** (peak_db / 20) / peak
    # 3 ms fade in/out against clicks.
    f = n_of(0.003)
    for i in range(min(f, len(b))):
        b[i] *= i / f
        b[-1 - i] *= i / f
    with wave.open(f'{OUT}/{name}.wav', 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, v * g)) * 32767)) for v in b))
    print('wrote', name, f'{len(b) / SR:.2f}s')


def hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


C5, D5, E5, G5, A5, C6, E6, G6 = (hz(n) for n in (72, 74, 76, 79, 81, 84, 88, 91))


def main():
    # UI ------------------------------------------------------------------
    save('tap', reverb(marimba(hz(84), 0.12, hard=0.3), wet=0.1), -6)
    save('button', reverb(mix([(0, marimba(hz(79), 0.12, 0.25), 1), (0.025, marimba(hz(86), 0.12, 0.2), 0.6)]), wet=0.12), -5)
    save('pop', reverb(soft(500, 0.09, f_end=1100, att=0.002, rel=0.05), wet=0.1), -4)
    save('swoosh', reverb(noise(0.28, 0.02, 0.35, seed=4), wet=0.15), -6)
    save('whoosh', reverb(noise(0.32, 0.3, 0.03, seed=7), wet=0.15), -6)
    save('tick', marimba(hz(96), 0.05, hard=0.2), -10)
    # Game pieces ---------------------------------------------------------
    save('flip', mix([(0, noise(0.06, 0.6, 0.2, seed=11), 0.7), (0.012, marimba(hz(81), 0.1, 0.2), 0.5)]), -5)
    save('slide', reverb(mix([(0, noise(0.12, 0.08, 0.15, seed=12), 0.8), (0.0, soft(300, 0.12, 'tri', f_end=380, att=0.01, rel=0.05), 0.3)]), wet=0.1), -6)
    save('place', reverb(mix([(0, marimba(hz(60), 0.16, 0.6), 1), (0, noise(0.03, 0.5, 0.5, seed=13, shape='exp', decay=120), 0.4)]), wet=0.1), -4)
    rnd = random.Random(21)
    rattle = [(i * 0.055 + rnd.uniform(0, 0.015), mix([(0, noise(0.035, 0.6, 0.6, seed=30 + i, shape='exp', decay=150), 1), (0, marimba(rnd.uniform(700, 1100), 0.06, 0.6), 0.35)]), 1 - i * 0.08) for i in range(7)]
    save('dice', reverb(mix(rattle), wet=0.1), -4)
    save('capture', reverb(mix([(0, marimba(hz(67), 0.25, 0.8), 1), (0.06, marimba(hz(62), 0.3, 0.8), 0.8), (0, noise(0.05, 0.6, 0.6, seed=14, shape='exp', decay=80), 0.5)]), wet=0.15), -4)
    # Rewards -------------------------------------------------------------
    save('coin', reverb(mix([(0, glass(hz(95), 0.3), 1), (0.06, glass(hz(100), 0.45), 0.9)]), wet=0.2), -6)
    save('coins', reverb(mix([(i * 0.055, glass(hz(95 + (i * 5) % 12), 0.35), 1 - i * 0.07) for i in range(8)]), wet=0.25), -6)
    save('success', reverb(mix([(0, marimba(C6, 0.3), 1), (0.08, marimba(E6, 0.3), 1), (0.16, marimba(G6, 0.5), 1)]), wet=0.2), -4)
    save('combo', reverb(mix([(i * 0.045, marimba(f, 0.15, 0.4), 1) for i, f in enumerate((hz(84), hz(88), hz(91), hz(96)))]), wet=0.15), -5)
    save('levelup', reverb(mix([(i * 0.07, marimba(f, 0.35), 1) for i, f in enumerate((C5, E5, G5, C6, E6))] + [(0.36, glass(G6, 0.9), 0.7)]), wet=0.25), -3)
    save('unlock', reverb(mix([(0, marimba(hz(72), 0.2, 0.7), 0.8), (0.07, glass(hz(84), 0.8), 1), (0.14, glass(hz(91), 0.8), 0.8), (0.05, noise(0.3, 0.3, 0.6, seed=15), 0.25)]), wet=0.3), -4)
    win = [(i * 0.1, marimba(f, 0.4), 1) for i, f in enumerate((G5, C6, E6))] + [(0.3, glass(G6, 1.1), 0.9), (0.3, glass(C6, 1.1), 0.6)]
    save('win', reverb(mix(win), wet=0.3), -3)
    cel = [(i * 0.09, marimba(f, 0.35), 1) for i, f in enumerate((C5, E5, G5, C6, E6, G6))]
    cel += [(0.55 + i * 0.07, glass(f, 0.9), 0.6) for i, f in enumerate((C6, E6, G6, hz(96)))]
    cel += [(0.55 + i * 0.06, noise(0.08, 0.6, 0.6, seed=40 + i, shape='exp', decay=50), 0.2) for i in range(6)]
    save('celebrate', reverb(mix(cel), wet=0.3), -3)
    # Mistakes (gentle, never harsh) -------------------------------------
    save('fail', reverb(mix([(0, soft(hz(64), 0.22, 'tri', rel=0.1), 1), (0.15, soft(hz(59), 0.4, 'tri', f_end=hz(57), rel=0.25), 1)]), wet=0.2), -6)
    save('buzzer', reverb(mix([(0, soft(196, 0.32, 'tri', vib=0.03, rel=0.1), 1), (0, soft(201, 0.32, 'tri', vib=0.03, rel=0.1), 0.8)]), wet=0.1), -6)


if __name__ == '__main__':
    main()
