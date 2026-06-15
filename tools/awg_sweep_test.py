#!/usr/bin/env python3
"""
AWG SFCW / FMCW Sweep Control Tool
Usage:
  python awg_sweep_test.py COM3 sfwc 1e6 100e6 1e6 0.1   # linear sweep
  python awg_sweep_test.py COM3 fmcw 1e6 50e6 1000 10     # chirp
  python awg_sweep_test.py COM3 log 1e3 100e6 8 0.5        # log sweep
"""
import serial, sys, time, math

REG = {
    'CONTROL':     0x08, 'STATUS': 0x0C,
    'PHASE_INC_LO': 0x10, 'PHASE_INC_HI': 0x14,
    'AMP':         0x20, 'WAVE_MODE': 0x28, 'APPLY': 0x2C,
    'SWEEP_START_LO': 0x50, 'SWEEP_START_HI': 0x54,
    'SWEEP_STOP_LO':  0x58, 'SWEEP_STOP_HI':  0x5C,
    'SWEEP_STEP_LO':  0x60, 'SWEEP_STEP_HI':  0x64,
    'SWEEP_DWELL':    0x68, 'SWEEP_CTRL':     0x6C,
}

FSYS = 1e9  # Effective sample rate (4 samples × 250MHz DDS clock)

class AWG:
    def __init__(self, port):
        self.ser = serial.Serial(port, 115200, timeout=1)
        time.sleep(0.5)
    def wr(self, addr, data):
        cmd = f'W {addr&0xFF:02X} {data&0xFFFFFFFF:08X}\n'
        self.ser.write(cmd.encode()); self.ser.flush()
        return self.ser.readline().decode().strip()
    def rd(self, addr):
        cmd = f'R {addr&0xFF:02X}\n'
        self.ser.write(cmd.encode()); self.ser.flush()
        return self.ser.readline().decode().strip()
    def freq_to_phase(self, f_hz):
        """Convert Hz to 48-bit phase increment (FS = 1 GHz effective)"""
        return int(f_hz * (2**48) / FSYS)
    def set_freq(self, f_hz):
        pi = self.freq_to_phase(f_hz)
        self.wr(REG['PHASE_INC_LO'], pi & 0xFFFFFFFF)
        self.wr(REG['PHASE_INC_HI'], (pi >> 32) & 0xFFFF)
    def apply(self):
        self.wr(REG['APPLY'], 1)
    def enable(self):
        self.wr(REG['CONTROL'], 0x03)
    def status(self):
        r = self.rd(REG['STATUS'])
        if r.startswith('D '):
            v = int(r.split()[-1], 16)
            return {
                'tx_ready': bool(v & 4), 'tx_sync': bool(v & 8),
                'sample_valid': bool(v & 0x10)
            }
        return None

def cmd_sfwc(awg, args):
    """SFCW: Stepped Frequency Continuous Wave"""
    f_start, f_stop, f_step, dwell_s = float(args[0]), float(args[1]), float(args[2]), float(args[3])
    print(f"SFCW: {f_start/1e6:.1f} → {f_stop/1e6:.1f} MHz, step {f_step/1e6:.3f} MHz, dwell {dwell_s}s")

    awg.enable()
    awg.wr(REG['WAVE_MODE'], 0)  # sine
    awg.wr(REG['AMP'], 0x6000)

    # Write sweep registers
    for name, addr_lo, addr_hi in [
        ('START', REG['SWEEP_START_LO'], REG['SWEEP_START_HI']),
        ('STOP',  REG['SWEEP_STOP_LO'],  REG['SWEEP_STOP_HI']),
        ('STEP',  REG['SWEEP_STEP_LO'],  REG['SWEEP_STEP_HI']),
    ]:
        pi = awg.freq_to_phase(eval(f'f_{name.lower()}'))
        awg.wr(addr_lo, pi & 0xFFFFFFFF)
        awg.wr(addr_hi, (pi >> 32) & 0xFFFF)

    dwell_ticks = int(dwell_s * FSYS)  # samples per step
    awg.wr(REG['SWEEP_DWELL'], dwell_ticks & 0xFFFFFFFF)

    # Start: enable, forward, linear
    awg.wr(REG['SWEEP_CTRL'], 0x01)  # bit0=enable
    print(f"SWEEP RUNNING — check spectrum analyzer (Max Hold)")
    print(f"Press Ctrl+C to stop...")
    try:
        while True: time.sleep(1)
    except KeyboardInterrupt:
        awg.wr(REG['SWEEP_CTRL'], 0x00)  # disable
        print("Stopped.")

def cmd_fmcw(awg, args):
    """FMCW: Frequency Modulated Continuous Wave (chirp)"""
    f_start, f_stop, chirp_rate_hz_s, duration_s = float(args[0]), float(args[1]), float(args[2]), float(args[3])
    print(f"FMCW Chirp: {f_start/1e6:.1f} → {f_stop/1e6:.1f} MHz, {chirp_rate_hz_s:.0f} Hz/s, {duration_s}s")
    print("NOTE: Requires DDS chirp ports connected in awg_top")
    # Chirp control is currently grounded (1'b0) in awg_top
    # Need to add register bank support for chirp parameters
    print("FMCW chirp register control not yet implemented in reg_bank")
    print("Chirp mode is in DDS module but needs register bank extension")

def cmd_log(awg, args):
    """Logarithmic sweep"""
    f_start, f_stop, steps_per_decade, dwell_s = float(args[0]), float(args[1]), int(args[2]), float(args[3])
    print(f"Log Sweep: {f_start:.1f} → {f_stop:.1f} Hz, {steps_per_decade} pts/decade, dwell {dwell_s}s")

    awg.enable()
    awg.wr(REG['WAVE_MODE'], 0)
    awg.wr(REG['AMP'], 0x6000)

    decades = math.log10(f_stop / f_start)
    n_steps = int(decades * steps_per_decade)
    ratio = 10 ** (1.0 / steps_per_decade)

    print(f"  {n_steps} frequency points over {decades:.1f} decades")
    print(f"  Frequency ratio per step: {ratio:.4f}")

    awg.wr(REG['SWEEP_START_LO'], awg.freq_to_phase(f_start) & 0xFFFFFFFF)
    awg.wr(REG['SWEEP_START_HI'], (awg.freq_to_phase(f_start) >> 32) & 0xFFFF)
    awg.wr(REG['SWEEP_STOP_LO'], awg.freq_to_phase(f_stop) & 0xFFFFFFFF)
    awg.wr(REG['SWEEP_STOP_HI'], (awg.freq_to_phase(f_stop) >> 32) & 0xFFFF)
    awg.wr(REG['SWEEP_DWELL'], int(dwell_s * FSYS) & 0xFFFFFFFF)
    # Enable + log mode
    awg.wr(REG['SWEEP_CTRL'], 0x05)  # bit0=enable, bit2=log_mode

    print("LOG SWEEP RUNNING — check spectrum analyzer")
    print("Press Ctrl+C to stop...")
    try:
        while True: time.sleep(1)
    except KeyboardInterrupt:
        awg.wr(REG['SWEEP_CTRL'], 0x00)
        print("Stopped.")

def cmd_status(awg):
    s = awg.status()
    if s:
        print(f"JESD: tx_ready={s['tx_ready']} tx_sync={s['tx_sync']} sample_valid={s['sample_valid']}")
    else:
        print("UART read failed")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)

    port = sys.argv[1]
    awg = AWG(port)

    if len(sys.argv) == 2 or sys.argv[2] == 'status':
        cmd_status(awg)
    elif sys.argv[2] == 'sfcw' and len(sys.argv) >= 7:
        cmd_sfwc(awg, sys.argv[3:7])
    elif sys.argv[2] == 'fmcw' and len(sys.argv) >= 7:
        cmd_fmcw(awg, sys.argv[3:7])
    elif sys.argv[2] == 'log' and len(sys.argv) >= 7:
        cmd_log(awg, sys.argv[3:7])
    else:
        print("Usage examples:")
        print("  python awg_sweep_test.py COM3 sfwc 1e6 100e6 1e6 0.1")
        print("  python awg_sweep_test.py COM3 log 1e3 100e6 8 0.5")
        print("  python awg_sweep_test.py COM3 status")

    awg.ser.close()
