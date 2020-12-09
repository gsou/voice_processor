import serial
import sys
import os

# Send to a MIDI serial port
with serial.Serial('/dev/ttyUSB0', 31250) as ser:
    with open(sys.argv[1], 'r') as f:
        i = 0
        for l in f.readlines():
            if len(l) > 0 and l[0] not in "0123456789abcdefABCDEF":
                continue

            try:
                dat = bytearray.fromhex(l.strip()[0:6])
                ser.write(b'\xFE')
                ser.write(i.to_bytes(1, byteorder='big'))
                ser.write(dat[0].to_bytes(1, byteorder='big'))
                ser.write(b'\xFF')
                ser.write(dat[1:])
                ser.flush()
                i = i+1
            except:
                pass
