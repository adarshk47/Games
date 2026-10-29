"""Third sound-effect set for Master G: bright retro "arcade" chiptune
(square / pulse / triangle waves, quick pitch sweeps). Pure Python, original.

    python make_sfx3.py OUT_DIR

Writes one WAV per Sound enum value (tap.wav, pop.wav, ... swoosh.wav).
"""
import random

from make_sfx2 import hz, mix, n_of, noise, save

SR = 22050  # same rate as make_sfx2 (its save() writes to sys.argv[1])


def chip(f, dur, wave='square', f_end=None, duty=0.5, att=0.002, rel=0.03, vib=0.0, arp=None):
    """Chiptune voice. [arp] = list of semitone offsets cycled every 30 ms."""
    n = n_of(dur)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        ff = f if f_end is None else f * (f_end / f) ** (i / n)
        if arp:
            ff *= 2 ** (arp[int(t / 0.03) % len(arp)] / 12)
        if vib:
            ff *= 1 + vib * (1 if int(t * 12) % 2 else -1)
        ph += ff / SR
        x = ph % 1.0
        if wave == 'square':
            v = 1.0 if x < duty else -1.0
        elif wave == 'tri':
            v = 4 * abs(x - 0.5) - 1
        else:
            v = 2 * x - 1
        e = min(1.0, t / att) * min(1.0, max(0.0, (dur - t) / rel))
        out.append(v * e * 0.6)
    return out


def bitcrush(x, steps=16):
    return [round(v * steps) / steps for v in x]


def main():
    C5, E5, G5, C6, E6, G6 = (hz(n) for n in (72, 76, 79, 84, 88, 91))
    # UI
    save('tap', chip(hz(88), 0.04, duty=0.25), -9)
    save('button', mix([(0, chip(hz(79), 0.04, duty=0.25), 1), (0.04, chip(hz(91), 0.05, duty=0.25), 1)]), -8)
    save('pop', chip(300, 0.08, f_end=1200, duty=0.5), -7)
    save('swoosh', bitcrush(noise(0.22, 0.05, 0.6, seed=4)), -8)
    save('whoosh', bitcrush(noise(0.25, 0.6, 0.05, seed=7)), -8)
    save('tick', chip(hz(96), 0.025, duty=0.125), -12)
    # Pieces
    save('flip', mix([(0, chip(600, 0.05, f_end=1400, duty=0.25), 1)]), -8)
    save('slide', chip(220, 0.12, 'tri', f_end=330), -6)
    save('place', mix([(0, chip(160, 0.09, 'tri', f_end=90), 1), (0, bitcrush(noise(0.03, 0.6, 0.6, seed=3, shape='exp', decay=150)), 0.5)]), -5)
    rnd = random.Random(9)
    save('dice', mix([(i * 0.05, bitcrush(noise(0.03, 0.7, 0.7, seed=60 + i, shape='exp', decay=160)), 1 - i * 0.08) for i in range(6)]
                     + [(0.3, chip(rnd.choice([hz(76), hz(79)]), 0.06, duty=0.25), 0.6)]), -5)
    save('capture', mix([(0, chip(hz(72), 0.08), 1), (0.07, chip(hz(67), 0.08), 1), (0.14, chip(hz(60), 0.14, f_end=hz(55)), 1)]), -6)
    # Rewards
    save('coin', mix([(0, chip(hz(83), 0.06, duty=0.5), 1), (0.06, chip(hz(88), 0.22, duty=0.5, rel=0.15), 1)]), -8)
    save('coins', mix([(i * 0.06, chip(hz(83 + (i % 3) * 5), 0.08, duty=0.5), 1) for i in range(8)]), -8)
    save('success', mix([(i * 0.07, chip(f, 0.09, duty=0.25), 1) for i, f in enumerate((C6, E6, G6))]), -7)
    save('combo', chip(hz(84), 0.2, duty=0.25, arp=[0, 4, 7, 12]), -8)
    save('levelup', mix([(i * 0.08, chip(f, 0.1, duty=0.25), 1) for i, f in enumerate((C5, E5, G5, C6, E6))] + [(0.4, chip(G6, 0.45, duty=0.25, vib=0.01, rel=0.3), 1)]), -6)
    save('unlock', mix([(0, chip(hz(72), 0.06), 1), (0.06, chip(hz(79), 0.06), 1), (0.12, chip(hz(84), 0.35, arp=[0, 7, 12], rel=0.2), 1)]), -7)
    win = [(i * 0.12, chip(f, 0.12 if i < 3 else 0.5, duty=0.25, rel=0.1 if i < 3 else 0.35), 1) for i, f in enumerate((G5, C6, E6, G6))]
    win += [(i * 0.12, chip(f / 2, 0.12 if i < 3 else 0.5, 'tri'), 0.6) for i, f in enumerate((G5, C6, E6, G6))]
    save('win', mix(win), -5)
    cel = [(i * 0.1, chip(f, 0.1, duty=0.25), 1) for i, f in enumerate((C5, C5, G5, G5, C6, E6))]
    cel += [(0.6, chip(C6, 0.7, duty=0.25, arp=[0, 4, 7, 12], rel=0.4), 1), (0.6, chip(C5, 0.7, 'tri', rel=0.4), 0.6)]
    save('celebrate', mix(cel), -5)
    # Mistakes
    save('fail', mix([(0, chip(hz(67), 0.15, duty=0.5), 1), (0.15, chip(hz(63), 0.15, duty=0.5), 1), (0.3, chip(hz(59), 0.35, duty=0.5, f_end=hz(55), rel=0.2), 1)]), -8)
    save('buzzer', chip(110, 0.35, 'saw', vib=0.03, rel=0.08), -9)


if __name__ == '__main__':
    main()
