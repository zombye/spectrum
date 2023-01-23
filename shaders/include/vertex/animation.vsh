#if !defined INCLUDE_VERTEX_ANIMATION
#define INCLUDE_VERTEX_ANIMATION

vec3 GrassDisplacement(vec3 position, float animationTime) {
	float height = 0.5 - at_midBlock.y / 64.0;

	float maxAngle  = 0.15 * height;
	      maxAngle *= gl_MultiTexCoord1.y / 240.0;

	const float windSpeed = 2.0; // meters / second
	const float windDir   = radians(45.0); // 0 deg -> +X, 90 deg -> +Z
	const vec2 wind = windSpeed * vec2(cos(windDir), sin(windDir));

	const float freqTemporal = 2.5; // texels / second
	const float freqSpatial  = freqTemporal / windSpeed; // texels / meter

	const ivec2 noiseResolution = textureSize(noisetex, 0);

	// Read noise texture for "wind"
	vec2 noiseUv  = freqSpatial * position.xz + mod(freqSpatial * cameraPosition.xz, noiseResolution);
	     noiseUv += mod(-freqSpatial * wind * animationTime, noiseResolution);
	vec2 noise  = TextureCubic(noisetex, noiseUv / noiseResolution).xy * 2.0 - 1.0;
	     noise += vec2(cos(windDir), sin(windDir)) * 0.5;

	// Based on noise, compute displacement that "Rotates" around base
	float theta, phi;
	if (abs(noise.y) < abs(noise.x)) {
		theta = maxAngle * abs(noise.x);
		phi   = noise.x > 0.0 ? radians(0.0) : radians(180.0);
		phi  += radians(45.0) * noise.y / noise.x;
	} else {
		theta = maxAngle * abs(noise.y);
		phi   = noise.y > 0.0 ? radians(90.0) : radians(270.0);
		phi  -= radians(45.0) * noise.x / noise.y;
	}
	vec3 disp = height * vec3(vec2(cos(phi), sin(phi)) * sin(theta), cos(theta) - 1.0).xzy;

	return disp;
}
vec3 TallGrassDisplacement(vec3 position, float animationTime, bool topHalf) {
	float height = (topHalf ? 1.5 : 0.5) - at_midBlock.y / 64.0;

	float maxAngle  = 0.1 * height;
	      maxAngle *= gl_MultiTexCoord1.y / 240.0;

	const float windSpeed = 2.0; // meters / second
	const float windDir   = radians(45.0); // 0 deg -> +X, 90 deg -> +Z
	const vec2 wind = windSpeed * vec2(cos(windDir), sin(windDir));

	const float freqTemporal = 2.5; // texels / second
	const float freqSpatial  = freqTemporal / windSpeed; // texels / meter

	// Get noise
	vec2 noiseUv  = freqSpatial * position.xz + mod(freqSpatial * cameraPosition.xz, 256.0);
	     noiseUv += mod(freqSpatial * wind * animationTime, 256.0);
	vec2 noise = TextureCubic(noisetex, noiseUv / 256.0).xy * 1.5 - 1.0;

	// Based on noise, compute displacement that "Rotates" around base
	vec3 disp;
	if (abs(noise.y) < abs(noise.x)) {
		float theta = maxAngle * abs(noise.x);
		float phi   = noise.x > 0.0 ? radians(0.0) : radians(180.0);
		      phi  += radians(45.0) * noise.y / noise.x;
		disp = height * vec3(vec2(cos(phi), sin(phi)) * sin(theta), cos(theta) - 1.0);
	} else {
		float theta = maxAngle * abs(noise.y);
		float phi   = noise.y > 0.0 ? radians(90.0) : radians(270.0);
		      phi  -= radians(45.0) * noise.x / noise.y;
		disp = height * vec3(vec2(cos(phi), sin(phi)) * sin(theta), cos(theta) - 1.0);
	}

	return disp.xzy;
}
vec3 LeavesDisplacement(vec3 position, float animationTime) {
	const float windSpeed = 2.0; // meters / second
	const float windDir   = radians(45.0); // 0 deg -> +X, 90 deg -> +Z
	const vec2 wind = windSpeed * vec2(cos(windDir), sin(windDir));

	const float freqTemporal = 2.0; // texels / second
	const float freqSpatial  = freqTemporal / windSpeed; // texels / meter

	const ivec2 noiseResolution = textureSize(noisetex, 0);

	vec2 noiseUv  = freqSpatial * position.xz + mod(freqSpatial * cameraPosition.xz, noiseResolution);
	     noiseUv += mod(-freqSpatial * wind * animationTime, noiseResolution);

	float iy = floor(freqSpatial * (position.y + cameraPosition.y));
	float fy = fract(freqSpatial * (position.y + cameraPosition.y));
	noiseUv += mod(vec2(97.0 * iy), noiseResolution);
	vec2 noiseUv0 = noiseUv;
	vec2 noiseUv1 = noiseUv + 97.0;

	vec3 noise0 = TextureCubic(noisetex, noiseUv0 / noiseResolution).xyz * 2.0 - 1.0;
	vec3 noise1 = TextureCubic(noisetex, noiseUv1 / noiseResolution).xyz * 2.0 - 1.0;

	vec3 disp  = mix(noise0, noise1, fy * fy * (3.0 - 2.0 * fy));
	     disp *= vec2(0.06, 0.03).xyx;

	disp *= gl_MultiTexCoord1.y / 240.0;

	return disp;
}

vec3 AnimateVertex(vec3 scenePosition, vec3 worldPosition, int id, float time) {
	time *= TIME_SCALE;

	if (id == 31) {
		return GrassDisplacement(scenePosition, time);
	} else if (id == 18) {
		return LeavesDisplacement(scenePosition, time);
	} else if (id == 175 || id == 176) {
		return TallGrassDisplacement(scenePosition, time, id == 176);
	}

	return vec3(0.0);
}

#endif
