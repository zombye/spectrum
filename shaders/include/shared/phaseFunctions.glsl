#if !defined INCLUDE_SHARED_PHASEFUNCTIONS
#define INCLUDE_SHARED_PHASEFUNCTIONS

float PhaseRayleigh(float cosTheta) {
	const float c = 3.0 / (16.0 * pi);
	return cosTheta * cosTheta * c + c;
}

float PhaseHenyeyGreenstein(float cosTheta, float g) {
	const float norm = 0.25 / pi;

	float gg = g * g;
	return (norm - norm * gg) * pow(1.0 + gg - 2.0 * g * cosTheta, -1.5);
}

// don't remember what exactly this one was supposed to be, should be renamed at some point
float PhaseMie(float cosTheta, float g) {
	float gg = g * g;
	float p1 = (0.375 * (1.0 - gg)) / (pi * (2.0 + gg));
	float p2 = (cosTheta * cosTheta + 1.0) * pow(-2.0 * g * cosTheta + 1.0 + gg, -1.5);
	return p1 * p2;
}

float PhaseFournierForand(float cosPhi, float n, float mu) {
	float phi = acos(cosPhi);

	// 0/0 at 2*asin((n - 1) * sqrt(3/4))

	// Not sure if this is correct.
	float v = (3.0 - mu) / 2.0;
	float delta = (4.0 / (3.0 * Pow2(n - 1.0))) * Pow2(sin(phi / 2.0));
	float delta180 = 4.0 / (3.0 * Pow2(n - 1.0));

	float p1 = (4.0 * pi * Pow2(1.0 - delta) * pow(delta, v));
	float p2 = v * (1.0 - delta) - (1.0 - pow(delta, v)) + (delta * (1.0 - pow(delta, v)) - v * (1.0 - delta)) / Pow2(sin(phi / 2.0));
	float p3 = ((1.0 - pow(delta180, v)) / (16.0 * pi * (delta180 - 1.0) * pow(delta180, v))) * (3.0 * cosPhi * cosPhi - 1.0);
	return p2 / p1 + p3;
}

#endif
