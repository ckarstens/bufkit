import os, sys
import datetime

now = datetime.datetime(2019,2,7,0,0,0)
delta = datetime.timedelta(hours=1)
end = datetime.datetime(2019,2,7,18,0,0)

while now <= end:
    last = now - datetime.timedelta(hours=1)
    cmd = 'php /local/ckarsten/bufkit/rap_' + last.strftime('%H') + '/scripts/rap/rap_bufkit.php now="' + now.strftime('%Y-%m-%d %H:%M:%S') + '" >& /local/ckarsten/bufkit/rap_' + last.strftime('%H') + '/scripts/rap/genOut.txt'
    print cmd
    os.system(cmd)
    break
    now += delta
