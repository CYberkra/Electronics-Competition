import subprocess
import sys
import time

from pathlib import Path

repo_root = Path(__file__).parent.resolve()

cmd = [
    r"D:\vivado\Vivado\2024.1\bin\vivado.bat",
    "-mode", "batch",
    "-source", str(repo_root / "build_key_freq.tcl")
]

log_file = repo_root / "build_key_freq.log"

print("Starting Vivado build...")
print(f"Command: {' '.join(cmd)}")

with open(log_file, "w", encoding="utf-8") as log:
    proc = subprocess.Popen(
        cmd,
        stdout=log,
        stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NEW_CONSOLE
    )
    print(f"Vivado PID: {proc.pid}")
    print("Log file: D:\\awg_fpga\\build_key_freq.log")
    print("Run 'type D:\\awg_fpga\\build_key_freq.log' to check progress.")
