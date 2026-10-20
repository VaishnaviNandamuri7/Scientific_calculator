#!/usr/bin/env python3
"""
decode_output.py -- read output.hex from the simulation, decode each word
the way the program meant it (int / float32 / Q16.16), and compare it with
a golden value computed in Python.

Usage:   python Tools/decode_output.py [path/to/output.hex]
Exit code: 0 if every check passes, 1 otherwise (so scripts can use it).

output.hex format (written by Top_RISC_tb): one 8-digit hex WORD per line,
line N = data memory word N = byte address 4*N.
"""
import math
import struct
import sys

# ---------------------------------------------------------------- decoders
# The file only holds bit patterns. How to read a word is decided by the
# program, so each decoder turns the same 32 bits into a different number.

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

# ---------------------------------------------------------------- the spec
# word index -> (label, decoder, golden value, tolerance)
# tolerance 0 = must match exactly (integers, FPU results).
# CORDIC is iterative, so it gets a small tolerance, in LSBs of Q16.16.
LSB = 1 / 65536.0

SPEC = {
    0: ("sum 5+4+3+2+1",   as_int,     15,                          0),
    1: ("1.5 * 2.0 (FPU)", as_float32, f32(f32(1.5) * f32(2.0)),    0),
    2: ("sin(1.0) (CORDIC)", as_q16_16, math.sin(1.0),              3 * LSB),
}

# ---------------------------------------------------------------- file reader
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

# ---------------------------------------------------------------- main
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

    # anything non-zero that the spec doesn't know about is worth a look
    extra = [(i, w) for i, w in enumerate(words) if i not in SPEC and w != 0]
    for i, w in extra:
        print(f"{4*i:#04x}  {w:08x}  (not in SPEC)")

    print("\nALL PASSED" if failures == 0 else f"\n{failures} FAILED")
    sys.exit(1 if failures else 0)

if __name__ == "__main__":
    main()
