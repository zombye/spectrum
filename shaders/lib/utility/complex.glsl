#if !defined INCLUDE_UTILITY_COMPLEX
#define INCLUDE_UTILITY_COMPLEX

struct ComplexFloat {
	float r;
	float i;
};
struct ComplexVec3 {
	vec3 r;
	vec3 i;
};

bool ComplexEqual(ComplexFloat a, ComplexFloat b) {
	return a.r == b.r && a.i == b.i;
}
bool ComplexEqual(ComplexVec3 a, ComplexVec3 b) {
	return a.r == b.r && a.i == b.i;
}
ComplexFloat ComplexConjugate(ComplexFloat x) {
	return ComplexFloat(x.r, -x.i);
}
ComplexVec3 ComplexConjugate(ComplexVec3 x) {
	return ComplexVec3(x.r, -x.i);
}
ComplexFloat ComplexAdd(ComplexFloat a, ComplexFloat b) {
	return ComplexFloat(a.r + b.r, a.i + b.i);
}
ComplexVec3 ComplexAdd(ComplexVec3 a, ComplexVec3 b) {
	return ComplexVec3(a.r + b.r, a.i + b.i);
}
ComplexFloat ComplexSub(ComplexFloat a, ComplexFloat b) {
	return ComplexFloat(a.r - b.r, a.i - b.i);
}
ComplexFloat ComplexSub(float a, ComplexFloat b) {
	return ComplexFloat(a - b.r, -b.i);
}
ComplexFloat ComplexSub(ComplexFloat a, float b) {
	return ComplexFloat(a.r - b, a.i);
}
ComplexVec3 ComplexSub(ComplexVec3 a, ComplexVec3 b) {
	return ComplexVec3(a.r - b.r, a.i - b.i);
}
ComplexVec3 ComplexSub(vec3 a, ComplexVec3 b) {
	return ComplexVec3(a - b.r, -b.i);
}
ComplexVec3 ComplexSub(ComplexVec3 a, vec3 b) {
	return ComplexVec3(a.r - b, a.i);
}
ComplexFloat ComplexMul(ComplexFloat a, ComplexFloat b) {
	return ComplexFloat(a.r * b.r - a.i * b.i, a.i * b.r + a.r * b.i);
}
ComplexFloat ComplexMul(float a, ComplexFloat b) {
	return ComplexFloat(a * b.r, a * b.i);
}
ComplexFloat ComplexMul(ComplexFloat a, float b) {
	return ComplexFloat(a.r * b, a.i * b);
}
ComplexVec3 ComplexMul(ComplexVec3 a, ComplexVec3 b) {
	return ComplexVec3(a.r * b.r - a.i * b.i, a.i * b.r + a.r * b.i);
}
ComplexVec3 ComplexMul(vec3 a, ComplexVec3 b) {
	return ComplexVec3(a * b.r, a.r * b.i);
}
ComplexVec3 ComplexMul(ComplexVec3 a, vec3 b) {
	return ComplexVec3(a.r * b.r, a.i * b.r);
}
ComplexFloat ComplexDiv(ComplexFloat a, ComplexFloat b) {
	ComplexFloat ret;
	float denom = b.r * b.r + b.i * b.i;
	ret.r = (a.r * b.r + a.i * b.i) / denom;
	ret.i = (a.i * b.r - a.r * b.i) / denom;
	return ret;
}
ComplexVec3 ComplexDiv(ComplexVec3 a, ComplexVec3 b) {
	ComplexVec3 ret;
	vec3 denom = b.r * b.r + b.i * b.i;
	ret.r = (a.r * b.r + a.i * b.i) / denom;
	ret.i = (a.i * b.r - a.r * b.i) / denom;
	return ret;
}
ComplexFloat ComplexRcp(ComplexFloat x) {
	float denom = x.r * x.r + x.i * x.i;
	return ComplexFloat(x.r / denom, -x.i / denom);
}
ComplexVec3 ComplexRcp(ComplexVec3 x) {
	vec3 denom = x.r * x.r + x.i * x.i;
	return ComplexVec3(x.r / denom, -x.i / denom);
}
ComplexFloat ComplexSqrt(ComplexFloat x) {
	ComplexFloat ret;
	float modulus = sqrt(x.r * x.r + x.i * x.i);
	ret.r =             sqrt(max((modulus + x.r) * 0.5, 0.0));
	ret.i = sign(x.i) * sqrt(max((modulus - x.r) * 0.5, 0.0));
	return ret;
}
ComplexVec3 ComplexSqrt(ComplexVec3 x) {
	ComplexVec3 ret;
	vec3 modulus = sqrt(x.r * x.r + x.i * x.i);
	ret.r =             sqrt(max((modulus + x.r) * 0.5, 0.0));
	ret.i = sign(x.i) * sqrt(max((modulus - x.r) * 0.5, 0.0));
	return ret;
}
float ComplexAbs(ComplexFloat x) {
	return sqrt(x.r * x.r + x.i * x.i);
}
vec3 ComplexAbs(ComplexVec3 x) {
	return sqrt(x.r * x.r + x.i * x.i);
}

ComplexFloat ComplexExp(ComplexFloat x) {
	return ComplexMul(exp(x.r), ComplexFloat(cos(x.i), sin(x.i)));
}

#endif
