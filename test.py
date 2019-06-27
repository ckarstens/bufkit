import os, sys

fh = open('global_stations_new.txt','r')
lines = fh.readlines()
fh.close()

i = 0
for line in lines:
   i += 1
   s = line.split(',')
   print float(s[0]), float(s[1]), i
