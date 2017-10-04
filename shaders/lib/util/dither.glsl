float bayer2(vec2 a) {
	a = floor(a);
	return fract(dot(a,vec2(0.5, a.y * 0.75)));
}
float bayer4  (vec2 a) { return bayer2 (0.500 * a) * 0.250000 + bayer2(a); }
float bayer8  (vec2 a) { return bayer4 (0.500 * a) * 0.250000 + bayer2(a); }
float bayer16 (vec2 a) { return bayer4 (0.250 * a) * 0.062500 + bayer4(a); }
float bayer32 (vec2 a) { return bayer8 (0.250 * a) * 0.062500 + bayer4(a); }
float bayer64 (vec2 a) { return bayer8 (0.125 * a) * 0.015625 + bayer8(a); }
float bayer128(vec2 a) { return bayer16(0.125 * a) * 0.015625 + bayer8(a); }

float bayerN(vec2 c, const int n) {
	c /= pow(2, n - 1);

	float w = 1.0 / pow(4, n - 1);
	float r = w * 0.25;

	for (float i = 0.0; i < n; i++, c *= 2.0, w *= 4.0) {
		vec2 flc = floor(c);
		r += fract(dot(flc, vec2(0.5, flc.y * 0.75))) * w;
	}

	return r;
}
