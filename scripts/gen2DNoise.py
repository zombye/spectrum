import math
import numpy as np
import png

resolution = 256
shift = 97

# generate values then shuffle them, instead of just generating random values
# this ensures a flat histogram
noise = np.zeros(resolution * resolution, 'uint8')
for r in range(int(resolution * resolution / 256)):
	for v in range(256):
		noise[r * 256 + v] = v
np.random.shuffle(noise)
noise = np.reshape(noise, (resolution, resolution))

# TODO: turn into blue noise here?
# possible algorithm idea for that:
# a pixel exerts a "force" on similar nearby values to "push" them away
# two nearby pixels are swapped if the net force put on them would decrease after the swap
# idk how well this would work but i'm pretty sure it _should_ work, right?

image = np.zeros((resolution, resolution, 3), 'uint8')
for x in range(resolution):
	for y in range(resolution):
		image[x, y, 0] = noise[x, y]

for x in range(resolution):
	for y in range(resolution):
		image[x, y, 1] = image[(x + shift) % resolution, (y + shift) % resolution, 0]

image_reshaped = np.reshape(image, (resolution, resolution * 3))

writer = png.Writer(width=resolution, height=resolution)
with open('./noise.png', 'wb') as file:
	writer.write(file, image_reshaped)
