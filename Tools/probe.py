import sys
import time
import serial

sys.path.insert(0, "Tools")
import load

program = load.read_program_hex("TB/program.hex")
program = program + [0] * (128 - len(program))
print("program ready,", len(program), "bytes")

print("opening COM5")
link = serial.Serial()
link.port = "COM5"
link.baudrate = 38400
link.timeout = 1
link.write_timeout = 3          # give up on a stuck write after 3 s
link.rtscts = False             # no hardware flow control
link.dsrdtr = False
link.xonxoff = False
link.open()
print("port open")

link.reset_input_buffer()
print("sending")
try:
    link.write(bytes([0xA5] + program))
    print("write finished")
except serial.SerialTimeoutException:
    print("WRITE TIMED OUT - the driver is not taking the bytes")
    link.close()
    sys.exit(1)

for i in range(8):
    time.sleep(0.5)
    print("after", (i + 1) * 0.5, "s:", link.in_waiting, "bytes waiting")

link.close()
print("done")