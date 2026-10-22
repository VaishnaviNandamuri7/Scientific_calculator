#!/usr/bin/env python3
"""
calc.py - a small calculator front end for the custom CPU (v0).

You type one calculation at a time:
    1.5 * 2.0        two numbers and an operator -> runs on the FPU (float32)
    sin 1.0          a function and a number     -> runs on the CORDIC (Q16.16)
Put spaces between the parts.

For every calculation the tool:
    1. checks the input and converts the numbers to the CPU's formats
    2. builds a tiny program and writes it to program.hex
    3. waits while YOU run the simulation in Vivado
    4. reads output.hex, decodes the result and compares it with Python's answer

Usage:  python Tools/calc.py [folder_where_xsim_writes_output.hex]
"""
import math
import os
import shutil
import struct
import sys

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------
# Paths are found relative to this file, so nothing is hardcoded.
TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(TOOLS_DIR)

# program.hex is saved here (Vivado copies it into the sim folder when it launches)
TB_DIR = os.path.join(REPO_ROOT, "TB")

# XSim runs in this folder, so output.hex appears here.
# If yours is different, pass the folder as the first argument.
DEFAULT_SIM_DIR = os.path.join(REPO_ROOT, "Scripts", "CALC_PRO", "CALC_PRO.sim",
                               "sim_1", "behav", "xsim")

# The program writes this number to memory word 1 when it finishes.
# If it is missing from output.hex, the simulation did not run our program.
DONE_MARKER = 0x600D600D

# Registers the generated program uses
REG_A = 1          # first number
REG_B = 2          # second number
REG_RESULT = 3     # result of the FPU or CORDIC instruction
REG_MARKER = 4     # holds DONE_MARKER

# FPU operations: operator -> (mnemonic, funct7)
FPU_OPS = {
    "+":  ("fadd", 0b0000000),
    "-":  ("fsub", 0b0000100),
    "*":  ("fmul", 0b0001000),
    "/":  ("fdiv", 0b0001100),
    "==": ("feq",  0b0010000),
    "<":  ("flt",  0b0010100),
    "<=": ("fle",  0b0011000),
}

# CORDIC functions: name -> (mnemonic, funct3)
CORDIC_FUNCS = {
    "sin":  ("csin",  0),
    "cos":  ("ccos",  1),
    "tan":  ("ctan",  2),
    "exp":  ("cexp",  3),
    "ln":   ("cln",   4),
    "sqrt": ("csqrt", 5),
}

# Comparisons give 0 or 1 instead of a float
COMPARE_OPS = ["==", "<", "<="]


# ---------------------------------------------------------------------------
# Number formats
# ---------------------------------------------------------------------------
def to_float32_bits(x):
    """Python number -> the 32 bits of an IEEE-754 single."""
    try:
        packed = struct.pack(">f", x)
    except OverflowError:
        raise ValueError("number is too big for float32")
    return struct.unpack(">I", packed)[0]


def to_q16_16_bits(x):
    """Python number -> 32 bits of Q16.16 fixed point (value * 65536)."""
    n = int(round(x * 65536))
    if n < -2147483648 or n > 2147483647:
        raise ValueError("number is outside the Q16.16 range (-32768 to 32767.99998)")
    return n & 0xFFFFFFFF


def as_signed(word):
    """32 bits -> signed integer."""
    if word >= 0x80000000:
        return word - 0x100000000
    return word


def from_float32_bits(word):
    """32 bits of an IEEE-754 single -> Python float."""
    packed = struct.pack(">I", word)
    return struct.unpack(">f", packed)[0]


def from_q16_16_bits(word):
    """32 bits of Q16.16 -> Python float."""
    return as_signed(word) / 65536.0


def round_to_float32(x):
    """Round a Python float to the nearest float32. Too big becomes infinity."""
    try:
        return from_float32_bits(to_float32_bits(x))
    except ValueError:
        if x > 0:
            return math.inf
        return -math.inf


# ---------------------------------------------------------------------------
# Reading the user's input
# ---------------------------------------------------------------------------
def read_number(text):
    """Turn text into a float, or raise ValueError with a clear message."""
    try:
        x = float(text)
    except ValueError:
        raise ValueError("'" + text + "' is not a number")
    if math.isnan(x) or math.isinf(x):
        raise ValueError("'" + text + "' is not a usable number")
    return x


def parse_input(line):
    """
    Returns a request: [unit, name, funct, bits_a, bits_b]
        unit   = "fpu" or "cordic"
        name   = the operator or function the user typed
        funct  = funct7 (fpu) or funct3 (cordic)
        bits_a = first number, already in the CPU's format
        bits_b = second number (fpu only), otherwise None
    Raises ValueError if the input is not valid.
    """
    parts = line.split()

    # Three parts: "a op b"  -> FPU
    if len(parts) == 3:
        op = parts[1]
        if op not in FPU_OPS:
            raise ValueError("unknown operator '" + op + "'. Use + - * / == < <=")
        a = read_number(parts[0])
        b = read_number(parts[2])
        funct7 = FPU_OPS[op][1]
        return ["fpu", op, funct7, to_float32_bits(a), to_float32_bits(b)]

    # Two parts: "fn x"  -> CORDIC
    if len(parts) == 2:
        name = parts[0]
        if name not in CORDIC_FUNCS:
            raise ValueError("unknown function '" + name + "'. Use sin cos tan exp ln sqrt")
        x = read_number(parts[1])
        if name == "ln" and x <= 0:
            raise ValueError("ln needs a number greater than 0")
        if name == "sqrt" and x < 0:
            raise ValueError("sqrt needs a number that is 0 or more")
        funct3 = CORDIC_FUNCS[name][1]
        return ["cordic", name, funct3, to_q16_16_bits(x), None]

    raise ValueError("type  a op b  (like 1.5 * 2.0)  or  fn x  (like sin 1.0)")


# ---------------------------------------------------------------------------
# Building the program (a tiny assembler: only the instructions we need)
# ---------------------------------------------------------------------------
def encode_lui(rd, imm20):
    return (imm20 << 12) | (rd << 7) | 0b0110111


def encode_addi(rd, rs1, imm12):
    return ((imm12 & 0xFFF) << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0b0010011


def encode_sw(rs2, rs1, imm12):
    upper = (imm12 >> 5) & 0x7F      # imm[11:5]
    lower = imm12 & 0x1F             # imm[4:0]
    return (upper << 25) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) | (lower << 7) | 0b0100011


def encode_fpu(funct7, rd, rs1, rs2):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0b1111110


def encode_cordic(funct3, rd, rs1):
    return (0 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0b1111111


HALT_WORD = 0x0000006F      # jal x0, 0  (jumps to itself forever)


def load_constant(program, rd, value):
    """
    Adds the instructions that put a 32-bit value into register rd.
    lui sets the upper 20 bits, addi adds the lower 12 bits.
    addi sign-extends its 12-bit number, so if bit 11 of the low part is 1
    it acts as a negative number and the upper part must be 1 higher.
    """
    low = value & 0xFFF
    if low >= 0x800:
        low = low - 0x1000           # treat as negative
    upper = ((value - low) >> 12) & 0xFFFFF

    program.append(["lui  x" + str(rd) + ", 0x" + format(upper, "05X"),
                    encode_lui(rd, upper)])
    if low != 0:
        program.append(["addi x" + str(rd) + ", x" + str(rd) + ", " + str(low),
                        encode_addi(rd, rd, low)])


def build_program(request):
    """Returns the program as a list of [text, 32-bit word]."""
    unit = request[0]
    name = request[1]
    funct = request[2]
    bits_a = request[3]
    bits_b = request[4]

    program = []
    load_constant(program, REG_A, bits_a)

    if unit == "fpu":
        load_constant(program, REG_B, bits_b)
        mnemonic = FPU_OPS[name][0]
        text = mnemonic + " x" + str(REG_RESULT) + ", x" + str(REG_A) + ", x" + str(REG_B)
        program.append([text, encode_fpu(funct, REG_RESULT, REG_A, REG_B)])
    else:
        mnemonic = CORDIC_FUNCS[name][0]
        text = mnemonic + " x" + str(REG_RESULT) + ", x" + str(REG_A)
        program.append([text, encode_cordic(funct, REG_RESULT, REG_A)])

    # result -> memory word 0
    program.append(["sw   x" + str(REG_RESULT) + ", 0(x0)",
                    encode_sw(REG_RESULT, 0, 0)])

    # marker -> memory word 1 (proves the program ran to the end)
    load_constant(program, REG_MARKER, DONE_MARKER)
    program.append(["sw   x" + str(REG_MARKER) + ", 4(x0)",
                    encode_sw(REG_MARKER, 0, 4)])

    program.append(["jal  x0, 0", HALT_WORD])
    return program


GENERATED_TAG = "// generated by calc.py"


def save_backup_if_handwritten(path):
    """
    If program.hex already exists and was NOT made by this tool (for example
    your hand-written program), copy it to program_backup_N.hex first,
    so it is never lost. Returns the backup path, or None.
    """
    if not os.path.isfile(path):
        return None

    f = open(path)
    first_line = f.readline()
    f.close()
    if first_line.startswith(GENERATED_TAG):
        return None

    folder = os.path.dirname(path)
    number = 1
    while os.path.exists(os.path.join(folder, "program_backup_" + str(number) + ".hex")):
        number = number + 1
    backup = os.path.join(folder, "program_backup_" + str(number) + ".hex")
    shutil.copyfile(path, backup)
    return backup


def write_program_hex(program, sim_dir):
    """
    Writes program.hex: one byte per line, lowest byte first (same as the IMU expects).
    Saved in TB/ and also straight into the sim folder if it exists.
    Returns the list of files written.
    """
    folders = [TB_DIR]
    if os.path.isdir(sim_dir):
        folders.append(sim_dir)

    written = []
    for folder in folders:
        if not os.path.isdir(folder):
            os.makedirs(folder)
        path = os.path.join(folder, "program.hex")
        if folder == TB_DIR:
            backup = save_backup_if_handwritten(path)
            if backup is not None:
                print("saved your existing program.hex as " + backup)
        f = open(path, "w")
        f.write(GENERATED_TAG + "\n")
        address = 0
        for item in program:
            text = item[0]
            word = item[1]
            f.write("// addr 0x%02X: %s -> 0x%08X\n" % (address, text, word))
            for byte_number in range(4):
                byte = (word >> (8 * byte_number)) & 0xFF
                f.write("%02X\n" % byte)
            address = address + 4
        f.close()
        written.append(path)
    return written


# ---------------------------------------------------------------------------
# Running the simulation (v0: you do it by hand)
# ---------------------------------------------------------------------------
def wait_for_simulation():
    print()
    sim_script = os.path.join(REPO_ROOT, "Scripts", "sim.tcl").replace("\\", "/")
    print("Now run the simulation in the Vivado Tcl console:")
    print("    source " + sim_script)
    input("Press Enter when it has finished... ")


def read_output_words(sim_dir, not_older_than):
    """
    Reads output.hex. Returns the list of words.
    Raises ValueError if the file is missing or older than our program.hex.
    """
    path = os.path.join(sim_dir, "output.hex")
    if not os.path.isfile(path):
        raise ValueError("output.hex not found in " + sim_dir)
    if os.path.getmtime(path) < not_older_than:
        raise ValueError("output.hex is older than program.hex, the simulation did not run again")

    words = []
    f = open(path)
    for line in f:
        line = line.strip()
        if line == "":
            continue
        if "x" in line.lower():
            raise ValueError("output.hex contains unknown (x) bits")
        words.append(int(line, 16))
    f.close()
    return words


# ---------------------------------------------------------------------------
# Python's own answer, for comparison
# ---------------------------------------------------------------------------
def expected_result(request):
    """
    Returns (value, tolerance). value is None if we cannot work it out.
    """
    unit = request[0]
    name = request[1]
    bits_a = request[3]
    bits_b = request[4]

    if unit == "fpu":
        a = from_float32_bits(bits_a)
        b = from_float32_bits(bits_b)
        value = None
        if name == "+":
            value = round_to_float32(a + b)
        elif name == "-":
            value = round_to_float32(a - b)
        elif name == "*":
            value = round_to_float32(a * b)
        elif name == "/":
            if b != 0:
                value = round_to_float32(a / b)

        if name in ["+", "-", "*", "/"]:
            if value is None:
                return None, 0.0
            # Python rounds to the NEAREST float32, but our FPU has no rounding
            # step, so it cuts the extra bits off (rounds toward zero).
            # That can differ by 1 ulp (the last bit), so allow 1 ulp of error.
            # 1 ulp is at most 2**-23 of the value.
            tolerance = abs(value) * (2.0 ** -23)
            return value, tolerance

        if name == "==":
            return float(a == b), 0.0
        if name == "<":
            return float(a < b), 0.0
        if name == "<=":
            return float(a <= b), 0.0

    # CORDIC: use the number as the hardware saw it (rounded to Q16.16)
    x = from_q16_16_bits(bits_a)
    value = None
    if name == "sin":
        value = math.sin(x)
    elif name == "cos":
        value = math.cos(x)
    elif name == "tan":
        value = math.tan(x)
    elif name == "exp":
        if x < 10.3:
            value = math.exp(x)       # bigger results saturate in the hardware
    elif name == "ln":
        value = math.log(x)
    elif name == "sqrt":
        value = math.sqrt(x)

    if value is None:
        return None, 0.0
    tolerance = 3.0e-4 + 3.0e-4 * abs(value)      # same as cordic_tb
    return value, tolerance


# ---------------------------------------------------------------------------
# One full calculation
# ---------------------------------------------------------------------------
def calculate(line, sim_dir):
    request = parse_input(line)
    unit = request[0]
    name = request[1]

    program = build_program(request)

    print()
    print("Program (" + str(len(program)) + " instructions, running on the "
          + unit.upper() + "):")
    address = 0
    for item in program:
        print("  0x%02X  %08X  %s" % (address, item[1], item[0]))
        address = address + 4

    written = write_program_hex(program, sim_dir)
    print()
    for path in written:
        print("wrote " + path)

    # output.hex must be newer than the program.hex we just wrote
    program_time = os.path.getmtime(written[0])

    wait_for_simulation()

    words = read_output_words(sim_dir, program_time)

    if len(words) < 2 or words[1] != DONE_MARKER:
        raise ValueError("done marker missing: the simulation did not finish our program "
                         "(old output.hex, timeout, or a missing halt?)")

    raw = words[0]

    # decode the result
    is_compare = (unit == "fpu" and name in COMPARE_OPS)
    if is_compare:
        got = float(raw)
        shown = "True" if raw == 1 else "False"
    elif unit == "fpu":
        got = from_float32_bits(raw)
        shown = repr(got)
    else:
        got = from_q16_16_bits(raw)
        shown = repr(got)

    print()
    print("result:    %s     (raw 0x%08X)" % (shown, raw))

    # notes about special hardware answers
    if unit == "cordic" and name == "exp" and raw == 0x7FFFFFFF:
        print("note:      exp result is too big for Q16.16, the hardware saturated")
    if unit == "cordic" and name == "exp" and raw == 0:
        print("note:      exp result is too small for Q16.16, the hardware gave 0")
    if unit == "fpu" and raw == 0x7FC00000 and not is_compare:
        print("note:      the FPU returned NaN")

    # compare with Python
    value, tolerance = expected_result(request)
    if value is None:
        print("expected:  (not compared for this input)")
    else:
        if got == value:
            error = 0.0              # also covers inf == inf
        else:
            error = abs(got - value)
        if error <= tolerance:
            verdict = "OK"
        else:
            verdict = "MISMATCH"
        print("expected:  %r     error %.3g  ->  %s" % (value, error, verdict))


# ---------------------------------------------------------------------------
# The REPL
# ---------------------------------------------------------------------------
def print_help():
    print("  a op b    FPU, float32.   op is one of:  +  -  *  /  ==  <  <=")
    print("            example:  1.5 * 2.0")
    print("  fn x      CORDIC, Q16.16. fn is one of:  sin cos tan exp ln sqrt")
    print("            example:  sin 1.0")
    print("  help      show this")
    print("  quit      leave")


def main():
    sim_dir = DEFAULT_SIM_DIR
    if len(sys.argv) > 1:
        sim_dir = sys.argv[1]

    print("CPU calculator (v0).  Type 'help' for the commands, 'quit' to leave.")
    print("output.hex is read from: " + sim_dir)

    while True:
        print()
        try:
            line = input("calc> ").strip()
        except EOFError:
            break

        if line == "":
            continue
        if line == "quit" or line == "exit":
            break
        if line == "help":
            print_help()
            continue

        try:
            calculate(line, sim_dir)
        except ValueError as problem:
            print("error: " + str(problem))


if __name__ == "__main__":
    main()