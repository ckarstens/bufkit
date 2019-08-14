"""Helper script for reprocessing manually."""
import datetime
import subprocess

now = datetime.datetime(2019, 2, 6, 12)
delta = datetime.timedelta(hours=6)
end = datetime.datetime(2019, 2, 7, 0)

while now <= end:
    cmd = now.strftime("python scripts/run_bufkit.py nam %Y %m %d %H")
    subprocess.call(cmd, shell=True)
    now += delta
