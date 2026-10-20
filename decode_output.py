#!/usr/bin/env python3
import math
import struct
import sys


def as_int(w):
    """Two's-complement signed 32-bit integer."""
    return w - (1 << 32) if w & 0x80000000 else w

def as_float32(w):
    """IEEE-754 single precision."""
    return struct.unpack(">f", struct.pack(">I", w))[0]

def as_q16_16(w):
    """Signed fixed point, 16 integer bits . 16 fraction bits (CORDIC format)."""
    return as_int(w) / 65536.0

def f32(x):
    """Round a Python float (64-bit) to the nearest float32, like the FPU would."""
    return struct.unpack(">f", struct.pack(">f", x))[0]

LSB = 1 / 65536.0

SPEC = {
    0: ("sum 5+4+3+2+1",   as_int,     15,                          0),
    1: ("1.5 * 2.0 (FPU)", as_float32, f32(f32(1.5) * f32(2.0)),    0),
    2: ("sin(1.0) (CORDIC)", as_q16_16, math.sin(1.0),              3 * LSB),
}


def read_words(path):
    words = []
    with open(path) as f:
        for n, line in enumerate(f, 1):
            line = line.split("//")[0].strip()
            if not line or line.startswith("@"):
                continue
            if "x" in line.lower() or "z" in line.lower():
                sys.exit(f"{path}:{n}: unknown bits '{line}' (uninitialised memory?)")
            words.append(int(line, 16))
    return words


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "output.hex"
    words = read_words(path)
    print(f"read {len(words)} words from {path}\n")
    print(f"{'addr':<6}{'raw':<10}{'what':<20}{'decoded':<14}{'expected':<14}{'error':<12}result")

    failures = 0
    for idx, (label, decode, golden, tol) in SPEC.items():
        if idx >= len(words):
            print(f"{4*idx:#04x}  missing from file")
            failures += 1
            continue
        raw = words[idx]
        got = decode(raw)
        err = abs(got - golden)
        ok = err <= tol
        failures += not ok
        print(f"{4*idx:#04x}  {raw:08x}  {label:<20}{got:<14.6g}{golden:<14.6g}"
              f"{err:<12.3g}{'PASS' if ok else 'FAIL'}")


    extra = [(i, w) for i, w in enumerate(words) if i not in SPEC and w != 0]
    for i, w in extra:
        print(f"{4*i:#04x}  {w:08x}  (not in SPEC)")

    print("\nALL PASSED" if failures == 0 else f"\n{failures} FAILED")
    sys.exit(1 if failures else 0)

if __name__ == "__main__":
    main()
