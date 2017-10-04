#define clamp01(x) clamp(x, 0, 1)
#define max0(x) max(x, 0)

float minof(vec3 x) { return min(min(x.x, x.y), x.z); }
float minof(vec4 x) { return min(min(x.x, x.y), min(x.z, x.w)); }

float almostIdentity(float x, float m, float n) {
	if (x > m) return x;
	float t = x / m;
	return (((2.0 * n - m) * t + (2.0 * m - 3.0 * n)) * t * t) + n;
}
