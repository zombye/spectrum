#if !defined INCLUDE_FRAGMENT_TONEMAP
#define INCLUDE_FRAGMENT_TONEMAP

float TonemapCurve(float x) {
	const float toeStrength    = TONEMAP_TOE_STRENGTH;
	const float toeLength      = TONEMAP_TOE_LENGTH * TONEMAP_TOE_LENGTH / 2;
	const float linearSlope    = TONEMAP_LINEAR_SLOPE;
	const float linearLength   = TONEMAP_LINEAR_LENGTH;
	const float shoulderCurve  = TONEMAP_SHOULDER_CURVE;
	const float shoulderLength = TONEMAP_SHOULDER_LENGTH;

	const float toeX     = toeLength;
	const float toeY     = linearSlope * toeLength * (1.0 - toeStrength);
	const float toePower = 1.0 / (1.0 - toeStrength);

	const float tm = toeY * pow(1.0 / toeX, toePower);

	const float lm = linearSlope;
	const float la = toeStrength == 1.0 ? -linearSlope * toeX : toeY - toeY * toePower;

	const float shoulderX = linearLength * (1.0 - toeY) / linearSlope + toeX;
	const float shoulderY = linearLength * (1.0 - toeY) + toeY;

	const float sim = linearSlope * shoulderLength / (1.0 - shoulderY);
	const float sia = -sim * shoulderX;
	const float som = (1.0 - shoulderY) / shoulderLength;
	const float soa = shoulderY;

	float y;
	if (x < toeX) {
		y = tm * pow(x, toePower);
	} else if (x < shoulderX) {
		y = lm * x + la;
	} else {
		y  = sim * x + sia;
		y /= pow(pow(y, 1.0 / shoulderCurve) + 1.0, shoulderCurve);
		y  = som * y + soa;
	}

	return y;
}
vec3 Tonemap(vec3 color) {
	for (int component = 0; component < 3; ++component) {
		color[component] = TonemapCurve(color[component]);
	}

	return color;
}

#endif
