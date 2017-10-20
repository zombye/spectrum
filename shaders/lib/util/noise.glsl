// the mod(x, pi) in these are to resolve any clear patterns at very large scales (due to float precision)
vec2 hash22(vec2 x) {
	x = fract(mod(x, pi) * vec2(10.214, 9.637));
	x += dot(x, x.yx + vec2(38.549, 37.759));
	return fract((x.x + x.y) * x);
}
vec4 hash42(vec2 x) {
	vec4 x2 = fract(mod(x, pi).xyxy * vec4(10.214, 9.637, 10.023, 9.821));
	x2 += dot(x2, x2.zwxy + vec4(38.549, 37.759, 38.011, 38.163));
	return fract((x2.x + x2.y + x2.z + x2.w) * x2);
}
