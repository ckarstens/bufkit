import os, sys

files = ['bgruven/bufrgruven/stations/gfs3_bufrstations.txt','bgruven/bufrgruven/stations/nam_bufrstations.txt','bgruven/bufrgruven/stations/rap_bufrstations.txt']

d = {}
for f in files:
    model = f.split('/')[-1].split('_')[0]
    d[model] = {}

    fh = open(f,'r')
    lines = fh.readlines()
    fh.close()

    for line in lines:
        # 000001   69.580  -140.180  YAJ   11  0 KOMAKUK                          YT       19     0 MAGS 9-95
        s = line.split()
        sNum = s[0]
        lat = s[1]
        lon = s[2]
        site = s[3].lower()
        d[model][site] = {'sNum':sNum,'lat':lat,'lon':lon}

# echo "".$lat[$i].",".$lon[$i].",".$sites[$i].",".$ewrf_sites[$i].",".$gfs.",".$nam.",".$ruc.",".$sref."\n";

l = []
sites = []
ewrf = '---'
sref = '---'
for site in d['gfs3']:
    nam = '---'
    rap = '---'
    if site in d['nam'].keys():
        nam = site
    if site in d['rap'].keys():
        rap = site
    s = d['gfs3'][site]['lat'] + ',' + d['gfs3'][site]['lon'] + ',' + site + ',---,' + site + ',' + nam + ',' + rap + ',---'
    l.append(s)
    sites.append(site)

for site in d['nam']:
    if site in sites:
        continue
    rap = '---'
    if site in d['rap'].keys():
        rap = site
    s = d['nam'][site]['lat'] + ',' + d['nam'][site]['lon'] + ',' + site + ',---,---,' + site + ',' + rap + ',---'
    l.append(s)
    sites.append(site)

for site in d['rap']:
    if site in sites:
        continue
    s = d['rap'][site]['lat'] + ',' + d['rap'][site]['lon'] + ',' + site + ',---,---,---,' + site + ',---'
    l.append(s)
    sites.append(site)

fh = open('global_stations_new.txt','w')
fh.write('\n'.join(l))
fh.close()
