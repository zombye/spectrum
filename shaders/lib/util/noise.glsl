vec2 hash22(vec2 p) {
	vec2 p2 = fract(p * vec2(10.214, 9.637));
	p2 += dot(p2, p2.yx + vec2(38.549, 37.759));
	return fract((p2.x + p2.y) * p2);
}

vec4 hash42(vec2 p) {
	vec4 p2 = fract(p.xyxy * vec4(10.214, 9.637, 10.023, 9.821));
	p2 += dot(p2, p2.zwxy + vec4(38.549, 37.759, 38.011, 38.163));
	return fract((p2.x + p2.y + p2.z + p2.w) * p2);
}
