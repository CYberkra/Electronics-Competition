import subprocess
import sys
import os

from pathlib import Path

script_dir = Path(__file__).parent.resolve()
repo_root = script_dir.parent

vivado_cmd = [
    r"D:\vivado\Vivado\2024.1\bin\vivado.bat",
    "-mode", "batch",
    "-source", str(repo_root / "scripts" / "rebuild_awg_base.tcl")
]

log_path = str(repo_root / "vivado" / "rebuild_run.log")
err_path = str(repo_root / "vivado" / "rebuild_run_err.log")

# Clean old logs
for p in [log_path, err_path]:
    if os.path.exists(p):
        os.remove(p)

print("Starting Vivado batch process...")
print(f"Command: {' '.join(vivado_cmd)}")
print(f"Log: {log_path}")

with open(log_path, "w") as out, open(err_path, "w") as err:
    proc = subprocess.Popen(vivado_cmd, stdout=out, stderr=err)
    print(f"SUCCESS: Vivado started as PID {proc.pid}")
    print("Process is running in background. Check log file for progress.")
