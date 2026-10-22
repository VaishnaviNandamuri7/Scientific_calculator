#!/usr/bin/env python3
"""
load.py - runs program.hex on the real board (Board_Top) instead of the simulation.

    1. reads program.hex (the same file the simulation reads)
    2. sends it to the board over the USB-UART:  0xA5, then 128 program bytes
    3. the board runs it and sends back the 64 data memory words (256 bytes)
    4. writes them to output.hex in the same format as the simulation

So calc.py works with the board without changes: when calc.py says
"run the simulation", run this in a second terminal, then press Enter in calc.py.

Usage:  python Tools/load.py COM5
        python Tools/load.py COM5 --program TB/program.hex --out-dir TB
Needs pyserial:  pip install pyserial
"""
import argparse
import os
import sys

import calc     # only for the folder names, so both tools use the same places

try:
    import serial
except ImportError:
    print("error: pyserial is not installed. Run:  pip install pyserial")
    sys.exit(1)

HEADER = 0xA5            # tells the board a program follows
PROGRAM_BYTES = 128      # size of the instruction memory (IMU)
RESULT_WORDS = 64        # size of the data memory, same as output.hex
BAUD = 38400             # must match CLKS_PER_BIT in Board_Top.v (1 MHz / 38400 = 26)


def read_program_hex(path):
    """
    Reads program.hex like $readmemh does: one hex byte per line, // starts a comment.
    Returns a list of byte values.
    """
    data = []
    f = open(path)
    for line_number, line in enumerate(f, 1):
        line = line.split("//")[0]          # drop the comment part
        for token in line.split():
            if token.startswith("@"):
                raise ValueError("line %d: @address lines are not supported" % line_number)
            value = int(token, 16)
            if value > 0xFF:
                raise ValueError("line %d: '%s' is not one byte" % (line_number, token))
            data.append(value)
    f.close()
    if len(data) == 0:
        raise ValueError(path + " has no program bytes")
    if len(data) > PROGRAM_BYTES:
        raise ValueError("program is %d bytes, the instruction memory holds %d"
                         % (len(data), PROGRAM_BYTES))
    return data


def run_on_board(port, program, timeout):
    """Sends the program, returns the 64 result words."""
    # the rest of the instruction memory is filled with zeros
    padded = program + [0] * (PROGRAM_BYTES - len(program))

    link = serial.Serial(port, BAUD, timeout=timeout)
    link.reset_input_buffer()               # throw away anything old
    link.write(bytes([HEADER] + padded))
    reply = link.read(RESULT_WORDS * 4)
    link.close()

    if len(reply) != RESULT_WORDS * 4:
        raise ValueError("board sent %d of %d bytes. Did the program reach the halt "
                         "(jal x0, 0)? Is the bitstream loaded and the COM port right?"
                         % (len(reply), RESULT_WORDS * 4))

    # each word arrives lowest byte first
    words = []
    for i in range(RESULT_WORDS):
        b = reply[4 * i: 4 * i + 4]
        words.append(b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24))
    return words


def write_output_hex(words, path):
    """Same format as Top_RISC_tb: one 8-digit hex word per line."""
    f = open(path, "w")
    for word in words:
        f.write("%08x\n" % word)
    f.close()


def main():
    # output.hex goes where calc.py looks for it: the xsim folder if it exists, else TB/
    default_out = calc.DEFAULT_SIM_DIR
    if not os.path.isdir(default_out):
        default_out = calc.TB_DIR

    parser = argparse.ArgumentParser(description="Run program.hex on the board")
    parser.add_argument("port", help="serial port of the board, e.g. COM5")
    parser.add_argument("--program", default=os.path.join(calc.TB_DIR, "program.hex"),
                        help="program to run (default: TB/program.hex)")
    parser.add_argument("--out-dir", default=default_out,
                        help="folder for output.hex (default: the folder calc.py reads)")
    parser.add_argument("--timeout", type=float, default=3.0,
                        help="seconds to wait for the board's answer")
    args = parser.parse_args()

    try:
        program = read_program_hex(args.program)
        print("sending %s (%d bytes) to %s" % (args.program, len(program), args.port))
        words = run_on_board(args.port, program, args.timeout)
    except (ValueError, OSError, serial.SerialException) as problem:
        print("error: " + str(problem))
        sys.exit(1)

    out_path = os.path.join(args.out_dir, "output.hex")
    write_output_hex(words, out_path)
    print("wrote " + out_path)
    print("word 0 (result) = 0x%08X" % words[0])
    print("word 1 (marker) = 0x%08X%s" % (words[1],
          "  (done marker found)" if words[1] == calc.DONE_MARKER else ""))


if __name__ == "__main__":
    main()
