import serial, sys
f = float(sys.argv[1]) if len(sys.argv) > 1 else 50_000
ser = serial.Serial('COM3', 115200, timeout=2)
def wr(a,d):
    ser.write(f'W {a&0xFF:02X} {d&0xFFFFFFFF:08X}\n'.encode())
    ser.flush(); ser.readline()
pi = int(f * (2**48) / 1e9)
wr(0x10, pi & 0xFFFFFFFF)
wr(0x14, (pi>>32) & 0xFFFF)
wr(0x2C, 1)
print(f'{f:g}Hz set')
ser.close()
