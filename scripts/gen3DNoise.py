import math
import numpy as np
import sys

resolution = 64
scale = 10

# fill cells for cell noise
cells = np.random.random_sample((scale, scale, scale, 3))

# create 3d image
image = np.empty((resolution, resolution, resolution, 2))
sys.stdout.write('slice 0/' + str(resolution))
for x in range(resolution):
	for y in range(resolution):
		for z in range(resolution):
			image[x, y, z, 0] = np.random.random_sample()

			refpos = ((np.array([x, y, z]) + 0.5) / resolution) * scale
			posi = np.floor(refpos)
			posf = refpos - posi

			dist = math.sqrt(2.75)
			for ox in range(-1, 2):
				for oy in range(-1, 2):
					for oz in range(-1, 2):
						offs = np.array([ox, oy, oz])
						index = (posi + offs) % scale
						cellvec = cells[int(index[0]), int(index[1]), int(index[2])] + offs - posf
						dist = min(dist, np.linalg.norm(cellvec))

			image[x, y, z, 1] = dist / math.sqrt(2.75)
	sys.stdout.write('\rslice ' + str(x+1) + '/' + str(resolution))
	sys.stdout.flush()

with open('./noise3d.dat', 'wb') as file:
	np.array(image * 255, 'uint8').tofile(file)
