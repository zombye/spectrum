#define transformPosition(x, matrix) (mat3(matrix) * (x) + matrix[3].xyz)

void swap(inout float a, inout float b) { float c = a; a = b; b = c; }

vec3 linearTosRGB(vec3 color) {
	return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055, vec3(greaterThan(color, vec3(0.0031308))));
}
vec3 sRGBToLinear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), vec3(greaterThan(color, vec3(0.04045))));
}

float transmittedScatteringIntegral(float od, const float coeff) {
	const float a = -coeff / log(2.0);
	const float b = -1.0 / coeff;
	const float c =  1.0 / coeff;

	return exp2(a * od) * b + c; // = ∫{0,od} e^(-coeff*x) dx
}
vec3 transmittedScatteringIntegral(float od, const vec3 coeff) {
	const vec3 a = -coeff / log(2.0);
	const vec3 b = -1.0 / coeff;
	const vec3 c =  1.0 / coeff;

	return exp2(a * od) * b + c; // = ∫{0,od} e^(-coeff*x) dx
}

vec2 pointOnSpiral(float index, float total) {
	index = sqrt(index * tau * 2.0);
	return vec2(sin(index), cos(index)) * index / sqrt(total * tau * 2.0);
}
