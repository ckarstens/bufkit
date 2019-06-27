import os, sys

inputFile = sys.argv[1]
outputFile = inputFile + '1'

print 'Fixing QPF for ' + inputFile

fh = open(inputFile,'r')
lines = fh.readlines()
fh.close()

data = []
get = False
for line in lines:
	s = line.rstrip().split(' ')
	if get and len(s) == 8 and int(s[1][7:9]) % 3 != 0:
		s[7] = '0.00'
		data.append(' '.join(s))
	else:
		data.append(line.rstrip())
	if 'P03M' in s:
                get = True

allData = '\n'.join(data)
fh = open(outputFile,'w')
fh.write(allData)
fh.close()

os.system("awk 'sub(\"$\", \"\\r\")' " + outputFile + " > " + inputFile)
os.system('rm ' + outputFile)
