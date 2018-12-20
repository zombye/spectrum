#if !defined INCLUDE_VERTEX_ANIMATION
#define INCLUDE_VERTEX_ANIMATION

vec4 TextureBilinear(sampler2D sampler, vec2 coord, ivec2 resolution) {
	coord = coord * resolution - 0.5;
	ivec2 i = ivec2(floor(coord));
	vec2 f = coord - i;

	vec4 s0 = texelFetch(sampler, (i + ivec2(0,0)) % resolution, 0);
	vec4 s1 = texelFetch(sampler, (i + ivec2(1,0)) % resolution, 0);
	vec4 s2 = texelFetch(sampler, (i + ivec2(0,1)) % resolution, 0);
	vec4 s3 = texelFetch(sampler, (i + ivec2(1,1)) % resolution, 0);

	return mix(mix(s0, s1, f.x), mix(s2, s3, f.x), f.y);
}
vec4 TextureBicubic(sampler2D sampler, vec2 coord) {
	ivec2 res = textureSize(sampler, 0);

	coord = coord * res - 0.5;

	vec2 f = fract(coord);
	coord -= f;

	vec2 ff = f * f;
	vec4 w0, w1;
	w0.xz = 1.0 - f; w0.xz *= w0.xz * w0.xz;
	w1.yw = ff * f;
	w1.xz = 3.0 * w1.yw + 4.0 - 6.0 * ff;
	w0.yw = 6.0 - w1.xz - w1.yw - w0.xz;

	vec4 s = w0 + w1;
	vec4 c = coord.xxyy + vec4(-0.5, 1.5, -0.5, 1.5) + w1 / s;
	c /= res.xxyy;

	vec2 m = s.xz / (s.xz + s.yw);
	return mix(
		mix(TextureBilinear(sampler, c.yw, res), TextureBilinear(sampler, c.xw, res), m.x),
		mix(TextureBilinear(sampler, c.yz, res), TextureBilinear(sampler, c.xz, res), m.x),
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

	vec2 noiseUv = worldPosition.xz + mod(time * 2.0, 64.0); // 7.2 km/h
	vec2 noise = TextureBicubic(noisetex, noiseUv / 64.0).xy * 1.5 - 1.0;
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

vec3 AnimateVertex(vec3 scenePosition, vec3 worldPosition, int id, float time) {
	if (id == 31) {
		return AnimatePlant(scenePosition, worldPosition, time);
	}

	return vec3(0.0);
}

#endif
