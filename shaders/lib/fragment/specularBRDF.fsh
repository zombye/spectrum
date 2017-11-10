vec3 mrp_sphere(vec3 rayDirection, vec3 sphereDirection, float sphereAngularRadius) {
	float RdotS = dot(rayDirection, sphereDirection);

	if (RdotS >= cos(sphereAngularRadius)) return rayDirection; // if intersecting sphere normalized most representative point == direction

	vec3
	mrp = RdotS * rayDirection - sphereDirection; // closest approach relative to sphere
	mrp = normalize(mrp) * sin(sphereAngularRadius) + sphereDirection; // closest point on sphere relative to origin | sin(sphereAngularRadius) == sphereRadius if sphere distance == 1

	return normalize(mrp); // normalize most representative point for the direction to use
}

float f0ToIOR(float f0) {
	f0 = sqrt(f0);
	f0 *= 0.99999; // Prevents divide by 0
	return (1.0 + f0) / (1.0 - f0);
}

float d_GGX(float NoH, float alpha2) {
	float p = NoH == 1.0 ? alpha2 : (NoH * alpha2 - NoH) * NoH + 1.0;
	return alpha2 / (pi * p * p);
}
float f_dielectric(float NoV, float eta) {
	float p = 1.0 - (eta * eta * (1.0 - NoV * NoV));
	if (p <= 0.0) return 1.0; p = sqrt(p);

	vec2 r = vec2(NoV, p);
	r = (eta * r - r.yx) / (eta * r + r.yx);
	r *= r; r *= 0.5; return r.x + r.y;
}
float v_smithGGXCorrelated(float NoV, float NoL, float alpha2) {
	vec2 delta = vec2(NoV, NoL);
	delta *= sqrt((-delta * alpha2 + delta) * delta + alpha2);
	return 0.5 / max(delta.x + delta.y, 1e-9);
}

float specularBRDF(vec3 view, vec3 normal, vec3 light, float reflectance, float alpha2) {
	vec3 halfVec = normalize(view + light);
	float NoV = clamp01(dot(normal, view));
	float NoH = clamp01(dot(normal, halfVec));
	float NoL = clamp01(dot(normal, light));

	float d = d_GGX(NoH, alpha2);
	float f = f_dielectric(NoV, 1.0 / f0ToIOR(reflectance));
	float v = v_smithGGXCorrelated(NoV, NoL, alpha2);

	return d * f * v * NoL;
}
