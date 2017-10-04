#define textureRaw(sampler, coord) texelFetch2D(sampler, ivec2(coord * textureSize2D(sampler, 0)), 0)

float textureShadow(sampler2D sampler, vec3 coord) {
	vec4 samples = step(coord.p, textureGather(sampler, coord.st));
	vec4 weights = (fract(coord.st * textureSize2D(sampler, 0) + 0.502).xxyy) * vec4(1,-1,1,-1) + vec4(0,1,0,1);
	return dot(samples, weights.yxxy * weights.zzww);
}

vec4 textureBicubic(sampler2D sampler, vec2 coord) {
	vec2 res = textureSize2D(sampler, 0);

	coord = coord * res - 0.5;

	vec2 f = fract(coord);
	coord -= f;

	vec2 ff = f * f;
	vec4 w0;
	vec4 w1;
	w0.xz = 1.0 - f; w0.xz *= w0.xz * w0.xz;
	w1.yw = ff * f;
	w1.xz = 3.0 * w1.yw + 4.0 - 6.0 * ff;
	w0.yw = 6.0 - w1.xz - w1.yw - w0.xz;

	vec4 s = w0 + w1;
	vec4 c = coord.xxyy + vec2(-0.5, 1.5).xyxy + w1 / s;
	c /= res.xxyy;

	vec2 m = s.xz / (s.xz + s.yw);
	return mix(
		mix(texture2D(sampler, c.yw), texture2D(sampler, c.xw), m.x),
		mix(texture2D(sampler, c.yz), texture2D(sampler, c.xz), m.x),
		m.y);
}

vec4 textureBicubicLod(sampler2D sampler, vec2 coord, int lod) {
	vec2 res = textureSize2D(sampler, lod);

	coord = coord * res - 0.5;

	vec2 f = fract(coord);
	coord -= f;

	vec2 ff = f * f;
	vec4 w0;
	vec4 w1;
	w0.xz = 1.0 - f; w0.xz *= w0.xz * w0.xz;
	w1.yw = ff * f;
	w1.xz = 3.0 * w1.yw + 4.0 - 6.0 * ff;
	w0.yw = 6.0 - w1.xz - w1.yw - w0.xz;

	vec4 s = w0 + w1;
	vec4 c = coord.xxyy + vec2(-0.5, 1.5).xyxy + w1 / s;
	c /= res.xxyy;

	vec2 m = s.xz / (s.xz + s.yw);
	return mix(
		mix(texture2DLod(sampler, c.yw, lod), texture2DLod(sampler, c.xw, lod), m.x),
		mix(texture2DLod(sampler, c.yz, lod), texture2DLod(sampler, c.xz, lod), m.x),
		m.y);
}
