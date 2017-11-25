float lightmapCurve(float lightmap, float falloff) {
	lightmap *= lightmap * lightmap;
	return lightmap * (-lightmap + 2.0) / (pow2(-falloff * lightmap + falloff) + 1.0);
}
vec2 lightmapCurve(vec2 lightmap, float falloff) {
	lightmap *= lightmap * lightmap;
	return lightmap * (-lightmap + 2.0) / (pow2(-falloff * lightmap + falloff) + 1.0);
}
