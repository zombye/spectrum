#define TERRAIN_DEFORMATION_MODE 0 // [0 1]

vec3 calculateWavingGrass(vec3 position) {
	if (gl_MultiTexCoord0.t > mc_midTexCoord.t) return position;

	float time = frameTimeCounter;
	const vec4 rateIntensity = vec4(1.3, 1.7, 2.5, 0.6) * pi;
	const vec4 rateDirection = vec4(0.5, 0.8, 0.4, 0.8) * pi;
	vec4 phaseIntensity = mat3x4(vec4(1.1, 0.7, 1.2, 1.3), vec4(0.4,-0.3, 0.1,-0.2), vec4(1.0, 2.0, 1.4, 0.7)) * position;
	vec4 phaseDirection = mat3x4(vec4(0.2, 0.6, 0.4, 0.3), vec4(0.0, 0.0, 0.0, 0.0), vec4(0.3, 0.1, 0.4, 0.2)) * position;

	float intensity = dot(sin(time * rateIntensity + phaseIntensity), vec4(0.2, 0.4, 0.1, 0.5));
	float direction = radians(dot(sin(time * rateDirection + phaseDirection), vec4(20.0, 15.0, 30.0, 25.0)) + 45.0);

	position.xz += (intensity * vec2(sin(direction), cos(direction)) * 0.07 - 0.04) * lightmap.y;

	return position;
}
vec3 calculateWavingLeaves(vec3 position) {
	float time = frameTimeCounter;

	const vec4 rateIntensity  = vec4(1.3, 1.7, 2.5, 0.6) * pi;
	const vec4 rateDirection1 = vec4(0.5, 0.8, 0.4, 0.8) * pi;
	const vec4 rateDirection2 = vec4(0.5, 0.8, 0.4, 1.0) * pi;
	vec4 phaseIntensity  = mat3x4(vec4(1.1, 0.7, 1.2, 1.3), vec4(0.4,-0.3, 0.1,-0.2), vec4(1.0, 2.0, 1.4, 0.7)) * position;
	vec4 phaseDirection1 = mat3x4(vec4(0.2, 0.6, 0.4, 0.3), vec4(0.0, 0.0, 0.0, 0.0), vec4(0.3, 0.1, 0.4, 0.2)) * position;
	vec4 phaseDirection2 = mat3x4(vec4(0.3, 0.5, 0.5, 0.4), vec4(0.0, 0.0, 0.0, 0.0), vec4(0.4, 0.2, 0.3, 0.1)) * position;

	float intensity = dot(sin(time * rateIntensity + phaseIntensity), vec4(0.2, 0.4, 0.1, 0.5));
	vec2 direction = radians(vec2(
		dot(sin(time * rateDirection1 + phaseDirection1), vec4(20.0, 15.0, 30.0, 25.0)),
		dot(sin(time * rateDirection2 + phaseDirection2), vec4(8.0, 17.0, 7.0, 4.0))
	) + 45.0);

	position.xyz += intensity * vec3(sin(direction.y) * sin(direction.x), cos(direction.y), sin(direction.y) * cos(direction.x)) * 0.05 * lightmap.y;

	return position;
}

vec3 calculateDisplacement(vec3 position) {
	position += cameraPosition;

	switch (int(mc_Entity.x)) {
		case 18:  // Leaves
			position = calculateWavingLeaves(position); break;
		case 31:  // Tallgrass & Fern
		case 37:  // Small flowers
		case 59:  // Wheat
		case 141: // Carrots
		case 142: // Potatoes
			position = calculateWavingGrass(position); break;
		default: break;
	}
	
	position -= cameraPosition;

	return position;
}
