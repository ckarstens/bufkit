import os, sys
import datetime

now = datetime.datetime(2019,2,5,20,0,0)
delta = datetime.timedelta(hours=6)
end = datetime.datetime(2019,2,6,14,0,0)

while now <= end:
    cmd = 'php nam_bufkit.php now="' + now.strftime('%Y-%m-%d %H:%M:%S') + '"'
    print cmd
    os.system(cmd)
    now += delta
