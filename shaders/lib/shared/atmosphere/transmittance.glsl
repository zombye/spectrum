#if !defined INCLUDE_SHARED_ATMOSPHERE_TRANSMITTANCE
#define INCLUDE_SHARED_ATMOSPHERE_TRANSMITTANCE

vec3 TextureRGBE8(sampler2D sampler, vec2 coord, ivec2 resolution) {
	coord = coord * resolution - 0.5;
	ivec2 i = ivec2(floor(coord));
	vec2 f = coord - i;

	vec3 s0 = DecodeRGBE8(texelFetch(sampler, i + ivec2(0,0), 0));
	vec3 s1 = DecodeRGBE8(texelFetch(sampler, i + ivec2(1,0), 0));
	vec3 s2 = DecodeRGBE8(texelFetch(sampler, i + ivec2(0,1), 0));
	vec3 s3 = DecodeRGBE8(texelFetch(sampler, i + ivec2(1,1), 0));

	return mix(mix(s0, s1, f.x), mix(s2, s3, f.x), f.y);
}
vec3 TextureRGBE8(sampler2D sampler, vec2 coord) {
	return TextureRGBE8(sampler, coord, textureSize(sampler, 0));
}
vec3 AtmosphereTransmittance(sampler2D sampler, float coreDistance, float cosViewZenithAngle) {
	vec2 coord = AtmosphereTransmittanceLookupUv(coreDistance, cosViewZenithAngle);
	     coord = AddUvMargin(coord, textureSize(sampler, 0));
	return TextureRGBE8(sampler, coord);
}
vec3 AtmosphereTransmittance(sampler2D sampler, float coreDistance, float cosViewZenithAngle, float distance) {
	// Transmittance from A to B is same as transmittance from B to A
	// Transmittance over a distance should always be done from the lowest point to the highest point.

	float endR  = sqrt(distance * distance + 2 * coreDistance * cosViewZenithAngle * distance + coreDistance * coreDistance);
	float endMu = (coreDistance * cosViewZenithAngle + distance) / endR;

	if (endR < coreDistance && cosViewZenithAngle < 0.0) {
		return AtmosphereTransmittance(sampler, endR, -endMu) / AtmosphereTransmittance(sampler, coreDistance, -cosViewZenithAngle);
	} else {
		return AtmosphereTransmittance(sampler, coreDistance, cosViewZenithAngle) / AtmosphereTransmittance(sampler, endR, endMu);
	}
}
vec3 AtmosphereTransmittance(sampler2D sampler, vec3 position, vec3 direction) {
	float coreDistance = length(position);
	return AtmosphereTransmittance(sampler, coreDistance, dot(position, direction) / coreDistance);
}
vec3 AtmosphereTransmittance(sampler2D sampler, vec3 position, vec3 direction, float distance) {
	float coreDistance = length(position);
	return AtmosphereTransmittance(sampler, coreDistance, dot(position, direction) / coreDistance, distance);
}

#endif
