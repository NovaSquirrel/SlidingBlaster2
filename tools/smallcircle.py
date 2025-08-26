#!/usr/bin/env python3
import math

angles = 32

out = []
for angle in range(angles + angles//4):
	a = (angle/angles)*2*math.pi
	v = (int(round(math.sin(a)*8)))
	out.append(v)
print(out)
