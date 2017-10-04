float pack2x8(vec2 x) {
	return dot(round(x * 255.0), vec2(1.0, 256.0) / 65535.0);
}
vec2 unpack2x8(float x) {
	x *= 255.99609375;
	vec2 r;
	r.y = floor(x);
	r.x = x - r.y;
	return r * vec2(1.00390625, 1.0 / 255.0);
}

//----------------------------------------------------------------------------//

vec2 packNormal(vec3 normal) {
	return normal.xy * inversesqrt(normal.z * 8.0 + 8.0) + 0.5;
}
vec3 unpackNormal(vec2 pack) {
	pack = pack * 4.0 - 2.0;
	float f = dot(pack, pack);
	return vec3(pack * sqrt(clamp(f * -0.25 + 1.0, 0.0, 1.0)), f * -0.5 + 1.0); // clamped because float inaccuracy sometimes causes negative values to be passed into the sqrt, resulting in non-numerical values.
}
