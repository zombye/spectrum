float sky_rayleighPhase(float cosTheta) {
	const vec2 mul_add = vec2(0.1, 0.28) / pi;
	return cosTheta * mul_add.x + mul_add.y; // optimized version from [Elek09], divided by 4 pi for energy conservation
}
float sky_miePhase(float cosTheta, float g) {
	float gg = g * g;
	float p1 = (0.75 * (1.0 - gg)) / (tau * (2.0 + gg));
	float p2 = (cosTheta * cosTheta + 1.0) * pow(1.0 + gg - 2.0 * g * cosTheta, -1.5);
	return p1 * p2;
}
