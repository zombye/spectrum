#if !defined INCLUDE_VERTEX_ANIMATION
#define INCLUDE_VERTEX_ANIMATION

vec4 TextureBicubic(sampler2D sampler, vec2 coord) {
	ivec2 res = textureSize(sampler, 0);

	coord = coord * res - 0.5;

	vec2 f = fract(coord);
	coord -= f;

	vec2 ff = f * f;

	vec2 w0 = ff * f;
	vec2 w3 = 1.0 - f; w3 *= w3 * w3;
	vec2 w1 = w3 + 6.0 * f - 2.0 * w0;
	vec2 w2 = 3.0 * w0 + 4.0 - 6.0 * ff;

	vec4 s = vec4(w3, w1) + vec4(w2, w0);
	vec4 c = coord.xyxy + vec4(w2, w0) / s;
	c.xy -= 0.5; c.zw += 1.5;
	c /= res.xyxy;

	vec2 m = s.zw / (s.xy + s.zw);
	return mix(
		mix(texture(sampler, c.xy), texture(sampler, c.zy), m.x),
		mix(texture(sampler, c.xw), texture(sampler, c.zw), m.x),
		m.y
	);
}

vec3 AnimatePlant(
	vec3  scenePosition,
	vec3  worldPosition,
	float time
) {
	bool isTopHalf = false; // TODO
	bool isTopEdge = gl_MultiTexCoord0.t < mc_midTexCoord.t;

	if (!(isTopHalf || isTopEdge)) { return vec3(0.0); }

	// Radius when rotating
	float radius  = fract(worldPosition.y);
	      radius  = radius < 1e-3 && isTopEdge ? 1.0 : radius;
	      radius += float(isTopHalf);

	// Determing rotation
	// km/h * 1000m / 3600s == m/s
	//  5.0 km/h ~= 1.39
	//  7.2 km/h == 2.00
	// 10.0 km/h ~= 2.78
	// 15.0 km/h ~= 4.16

	vec2 noiseUv = worldPosition.xz + mod(time * 2.0, 256.0); // 7.2 km/h
	vec2 noise = TextureBicubic(noisetex, noiseUv / 256.0).xy * 1.5 - 1.0;
	vec2 rotation = vec2(atan(noise.y, noise.x), length(noise.xy) * MaxOf(abs(normalize(noise.xy))) * 0.2);
	if (isTopHalf && isTopEdge) {
		rotation *= 1.5;
	}

	// Fade out with skylight
	rotation.y *= gl_MultiTexCoord1.t / 240.0;

	// Rotate around bottom vertex
	vec3 disp = vec3(radius * SinCos(rotation.x) * sin(rotation.y), radius * cos(rotation.y) - radius).xzy;

	//* "grass stepping" effect
	float nearFactor = smoothstep(2.0, 1.0, length(scenePosition * vec3(2.0, 1.0, 2.0) + vec3(0.0, -1.2, 0.0)));
	vec3 direction = normalize(scenePosition * vec3(2.0, 1.0, 2.0) + vec3(0.0, -2.2, 0.0));
	disp = disp * (-0.7 * nearFactor + 1.0) + (direction * nearFactor * 0.5 * radius);
	//*/

	return disp;
}
vec3 AnimateLeaves(vec3 position, float time) {
	const vec4 rateIntensity  = vec4(4.08, 5.34, 7.85, 1.88);
	const vec4 rateDirection1 = vec4(1.57, 2.51, 1.26, 2.51);
	const vec4 rateDirection2 = vec4(1.57, 2.51, 1.26, 3.14);
	vec4 phaseIntensity  = mat3x4(vec4(1.1, 0.7, 1.2, 1.3), vec4(0.4,-0.3, 0.1,-0.2), vec4(1.0, 2.0, 1.4, 0.7)) * position;
	vec4 phaseDirection1 = mat3x4(vec4(0.2, 0.6, 0.4, 0.3), vec4(0.0, 0.0, 0.0, 0.0), vec4(0.3, 0.1, 0.4, 0.2)) * position;
	vec4 phaseDirection2 = mat3x4(vec4(0.3, 0.5, 0.5, 0.4), vec4(0.0, 0.0, 0.0, 0.0), vec4(0.4, 0.2, 0.3, 0.1)) * position;

	float intensity = dot(sin(time * rateIntensity + phaseIntensity), vec4(0.2, 0.4, 0.1, 0.5));
	vec2 direction = radians(vec2(
		dot(sin(time * rateDirection1 + phaseDirection1), vec4(20.0, 15.0, 30.0, 25.0)),
		dot(sin(time * rateDirection2 + phaseDirection2), vec4(8.0, 17.0, 7.0, 4.0))
	) + 45.0);

	vec3 displacementMain = intensity * vec3(sin(direction.y) * sin(direction.x), cos(direction.y), sin(direction.y) * cos(direction.x)) * 0.04;

	const vec4 detailRateIntensity  = vec4(15.8, 31.6, 37.6, 78.5);
	const vec4 detailRateDirection1 = vec4(20.2, 31.4, 25.2, 50.2);
	const vec4 detailRateDirection2 = vec4(20.2, 31.4, 25.2, 62.8);
	vec4 detailPhaseIntensity  = mat3x4(vec4(1.1, 0.7, 1.2, 1.3), vec4(0.4,-0.3, 0.1,-0.2), vec4(1.0, 2.0, 1.4, 0.7)) * 10.0 * position;
	vec4 detailphaseDirection1 = mat3x4(vec4(0.2, 0.6, 0.4, 0.3), vec4(0.0, 0.0, 0.0, 0.0), vec4(0.3, 0.1, 0.4, 0.2)) * 10.0 * position;
	vec4 detailphaseDirection2 = mat3x4(vec4(0.3, 0.5, 0.5, 0.4), vec4(0.0, 0.0, 0.0, 0.0), vec4(0.4, 0.2, 0.3, 0.1)) * 10.0 * position;

	float detailIntensity = dot(sin(time * detailRateIntensity + detailPhaseIntensity), vec4(0.14, 0.09, 0.06, 0.04));
	vec2 detailDirection = radians(vec2(
		dot(sin(time * detailRateDirection1 + detailphaseDirection1), vec4(20.0, 20.0, 10.0, 5.0)),
		dot(sin(time * detailRateDirection2 + detailphaseDirection2), vec4(8.0, 8.0, 4.0, 2.0))
	) + 45.0);

	vec3 displacementDetail = detailIntensity * vec3(sin(detailDirection.y) * sin(detailDirection.x), cos(detailDirection.y), sin(detailDirection.y) * cos(detailDirection.x)) * 0.02;

	return displacementMain + displacementDetail;
}

vec3 AnimateVertex(vec3 scenePosition, vec3 worldPosition, int id, float time) {
	time *= TIME_SCALE;

	if (id == 31) {
		return AnimatePlant(scenePosition, worldPosition, time);
	} else if (id == 18) {
		return AnimateLeaves(worldPosition, time);
	}

	return vec3(0.0);
}

#endif
