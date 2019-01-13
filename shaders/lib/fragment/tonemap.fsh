#if !defined INCLUDE_FRAGMENT_TONEMAP
#define INCLUDE_FRAGMENT_TONEMAP

vec3 Tonemap(vec3 color) {
	const float toeStrength    = TONEMAP_TOE_STRENGTH;
	const float toeLength      = TONEMAP_TOE_LENGTH * TONEMAP_TOE_LENGTH / 2;
	const float linearSlope    = TONEMAP_LINEAR_SLOPE;
	const float linearLength   = TONEMAP_LINEAR_LENGTH;
	const float shoulderCurve  = TONEMAP_SHOULDER_CURVE;
	const float shoulderLength = TONEMAP_SHOULDER_LENGTH;

	const float toeX     = toeLength;
	const float toeY     = linearSlope * toeLength * (1.0 - toeStrength);
	const float toePower = 1.0 / (1.0 - toeStrength);

	const float tim = 1.0 / toeX;
	const float tom = toeY;

	const float lm = linearSlope;
	const float la = toeStrength == 1.0 ? -linearSlope * toeX : toeY - toeY * toePower;

	const float shoulderX = linearLength * (1.0 - toeY) / linearSlope + toeX;
	const float shoulderY = linearLength * (1.0 - toeY) + toeY;

	const float sim = linearSlope * shoulderLength / (1.0 - shoulderY);
	const float sia = -sim * shoulderX;
	const float som = (1.0 - shoulderY) / shoulderLength;
	const float soa = shoulderY;

	for (int i = 0; i < 3; ++i) {
		if (color[i] < toeX) {
			color[i] = tom * pow(tim * color[i], toePower);
		} else if (color[i] < shoulderX) {
			color[i] = lm * color[i] + la;
		} else {
			color[i]  = sim * color[i] + sia;
			color[i] /= pow(pow(color[i], 1.0 / shoulderCurve) + 1.0, shoulderCurve);
			color[i]  = som * color[i] + soa;
		}
	}

	return color;
}

#endif
