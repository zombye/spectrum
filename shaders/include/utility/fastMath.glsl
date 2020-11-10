#if !defined INCLUDE_UTILITY_MATH
#define INCLUDE_UTILITY_MATH

// Faster alternative to acos when exact results are not needed.
// Intersects acos at: -1, -0.57985216912, 0, 0.57985216912, 1
// Max absolute error: 0.00426165254821 (~0.244 degrees)
// Max absolute error can be reduced if you are fine with it being discontinuous at 0 (i'm not)
float FastAcos(float x) {
	// abs() is free on input for GCN
	// I'm assuming that this is true for most modern GPUs.
	float r = sqrt(1.0 - abs(x)) * (-0.175394 * abs(x) + hpi);
	return x < 0.0 ? pi - r : r;
}
// One sub slower than facos but aside from that has the same properties.
float FastAsin(float x) {
	return hpi - FastAcos(x);
}

// Fast(-er) pow() for certain powers (mostly integers)
float Pow2(float x) { return x * x; }
vec2  Pow2(vec2  x) { return x * x; }
vec3  Pow2(vec3  x) { return x * x; }
vec4  Pow2(vec4  x) { return x * x; }
float Pow3(float x) { return x * x * x; }
vec2  Pow3(vec2  x) { return x * x * x; }
float Pow4(float x) { x *= x; return x * x; }
vec2  Pow4(vec2  x) { x *= x; return x * x; }
vec3  Pow4(vec3  x) { x *= x; return x * x; }
float Pow5(float x) { float x2 = x * x; return x2 * x2 * x; }
float Pow6(float x) { x *= x; return x * x * x; }
float Pow8(float x) { x *= x; x *= x; return x * x; }
float Pow12(float x) { x *= x; x *= x; return x * x * x; }
float Pow16(float x) { x *= x; x *= x; x *= x; return x * x; }

#endif
