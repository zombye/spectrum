import math
import numpy as np
import sys

resolutionHor  = 256
resolutionVert = 256
scale = 20

# fill cells for cell noise
cells0 = np.random.random_sample((scale  , scale  , scale  , 3))
cells1 = np.random.random_sample((scale*2, scale*2, scale*2, 3))
cells2 = np.random.random_sample((scale*4, scale*4, scale*4, 3))
cells3 = np.random.random_sample((scale*8, scale*8, scale*8, 3))

# create 3d image
image = np.empty((resolutionHor, resolutionHor, resolutionVert, 4))
sys.stdout.write('slice 0/' + str(resolutionVert))
for x in range(resolutionHor):
	for y in range(resolutionHor):
		for z in range(resolutionVert):
			refpos0 = ((np.array([x, y, z]) + 0.5) / resolutionHor) * scale
			refpos1 = ((np.array([x, y, z]) + 0.5) / resolutionHor) * scale*2
			refpos2 = ((np.array([x, y, z]) + 0.5) / resolutionHor) * scale*4
			refpos3 = ((np.array([x, y, z]) + 0.5) / resolutionHor) * scale*8
			posi0 = np.floor(refpos0)
			posi1 = np.floor(refpos1)
			posi2 = np.floor(refpos2)
			posi3 = np.floor(refpos3)
			posf0 = refpos0 - posi0
			posf1 = refpos1 - posi1
			posf2 = refpos2 - posi2
			posf3 = refpos3 - posi3

			dist0 = math.sqrt(2.75)
			dist1 = math.sqrt(2.75)
			dist2 = math.sqrt(2.75)
			dist3 = math.sqrt(2.75)
			for ox in range(-1, 2):
				for oy in range(-1, 2):
					for oz in range(-1, 2):
						offs = np.array([ox, oy, oz])
						index0 = (posi0 + offs) % scale
						index1 = (posi1 + offs) % scale*2
						index2 = (posi2 + offs) % scale*4
						index3 = (posi3 + offs) % scale*8
						cellvec0 = cells0[int(index0[0]), int(index0[1]), int(index0[2])] + offs - posf0
						cellvec1 = cells1[int(index1[0]), int(index1[1]), int(index1[2])] + offs - posf1
						cellvec2 = cells2[int(index2[0]), int(index2[1]), int(index2[2])] + offs - posf2
						cellvec3 = cells3[int(index3[0]), int(index3[1]), int(index3[2])] + offs - posf3
						dist0 = min(dist0, np.linalg.norm(cellvec0))
						dist1 = min(dist1, np.linalg.norm(cellvec1))
						dist2 = min(dist2, np.linalg.norm(cellvec2))
						dist3 = min(dist3, np.linalg.norm(cellvec3))

			image[x, y, z, 0] = dist0 / math.sqrt(2.75)
			image[x, y, z, 1] = dist1 / math.sqrt(2.75)
			image[x, y, z, 2] = dist2 / math.sqrt(2.75)
			image[x, y, z, 3] = dist3 / math.sqrt(2.75)
	sys.stdout.write('\rslice ' + str(x+1) + '/' + str(resolutionVert))
	sys.stdout.flush()

with open('./waterNoise.dat', 'wb') as file:
	np.array(image * 255, 'uint8').tofile(file)
