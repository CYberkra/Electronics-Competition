"""Quick test: EC11 encoder + TFT screen verification"""
import serial, time, sys

PORT = sys.argv[1] if len(sys.argv) > 1 else 'COM3'
FS = 1e9
ser = serial.Serial(PORT, 115200, timeout=1)

def wr(a, d):
    ser.write(f'W {a&0xFF:02X} {d&0xFFFFFFFF:08X}\n'.encode()); ser.flush()
    return ser.readline().decode().strip()

def rd(a):
    ser.write(f'R {a&0xFF:02X}\n'.encode()); ser.flush()
    r = ser.readline().decode().strip()
    return int(r.split()[-1], 16) if r.startswith('D ') else None

time.sleep(2)
print("Enable:", wr(0x08, 0x03))
print("ID:", hex(rd(0x00) or 0))

print("\n=== ROTATE EC11 NOW! (15 seconds) ===")
last_f = rd(0x10)
last_w = rd(0x28)
changes = 0

for i in range(60):
    f = rd(0x10)
    w = rd(0x28)
    if f != last_f:
        hz = f * FS / 2**48 if f else 0
        print(f"  ROTATE! {hz/1e6:.3f} MHz")
        last_f = f
        changes += 1
    if w != last_w:
        names = {0:'Sine', 1:'Triangle', 2:'Square', 3:'Saw'}
        print(f"  BUTTON! {names.get(w, str(w))}")
        last_w = w
        changes += 1
    time.sleep(0.2)

print(f"\nChanges detected: {changes}")
print("EC11: WORKING" if changes > 0 else "EC11: NO RESPONSE")
ser.close()
