// the mod(x, pi) in these are to resolve any clear patterns at very large scales (due to float precision)
vec2 hash22(vec2 x) {
	x = fract(mod(x, pi) * vec2(10.214, 9.637));
	x += dot(x, x.yx + vec2(38.549, 37.759));
	return fract((x.x + x.y) * x);
}
vec4 hash42(vec2 x) {
	vec4 x2 = fract(mod(x.xyyx, pi) * vec2(10.214, 9.637).xyxy);
	x2.xy += dot(x2.xy, x2.yx + vec2(38.549, 37.759));
	x2.zw += dot(x2.zw, x2.wz + vec2(38.549, 37.759));
	return fract((x2.xxzz + x2.yyww) * x2);
}
