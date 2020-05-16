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
ComplexFloat ComplexConjugate(ComplexFloat z) {
	return ComplexFloat(z.r, -z.i);
}
ComplexVec3 ComplexConjugate(ComplexVec3 z) {
	return ComplexVec3(z.r, -z.i);
}
ComplexFloat ComplexAdd(ComplexFloat a, ComplexFloat b) {
	return ComplexFloat(a.r + b.r, a.i + b.i);
}
ComplexVec3 ComplexAdd(ComplexVec3 a, ComplexVec3 b) {
	return ComplexVec3(a.r + b.r, a.i + b.i);
}
ComplexVec3 ComplexAdd(ComplexVec3 a, float b) {
	return ComplexVec3(a.r + b, a.i);
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
ComplexVec3 ComplexSub(float a, ComplexVec3 b) {
	return ComplexVec3(a - b.r, -b.i);
}
ComplexVec3 ComplexSub(ComplexVec3 a, vec3 b) {
	return ComplexVec3(a.r - b, a.i);
}
ComplexVec3 ComplexSub(ComplexVec3 a, float b) {
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
	return ComplexVec3(a * b.r, a * b.i);
}
ComplexVec3 ComplexMul(ComplexVec3 a, vec3 b) {
	return ComplexVec3(a.r * b, a.i * b);
}
ComplexVec3 ComplexMul(ComplexVec3 a, float b) {
	return ComplexVec3(a.r * b, a.i * b);
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
ComplexFloat ComplexRcp(ComplexFloat z) {
	float denom = z.r * z.r + z.i * z.i;
	return ComplexFloat(z.r / denom, -z.i / denom);
}
ComplexVec3 ComplexRcp(ComplexVec3 z) {
	vec3 denom = z.r * z.r + z.i * z.i;
	return ComplexVec3(z.r / denom, -z.i / denom);
}
ComplexFloat ComplexSqrt(ComplexFloat z) {
	ComplexFloat ret;
	float modulus = sqrt(z.r * z.r + z.i * z.i);
	ret.r =             sqrt(max((modulus + z.r) * 0.5, 0.0));
	ret.i = sign(z.i) * sqrt(max((modulus - z.r) * 0.5, 0.0));
	return ret;
}
ComplexVec3 ComplexSqrt(ComplexVec3 z) {
	ComplexVec3 ret;
	vec3 modulus = sqrt(z.r * z.r + z.i * z.i);
	ret.r =             sqrt(max((modulus + z.r) * 0.5, 0.0));
	ret.i = sign(z.i) * sqrt(max((modulus - z.r) * 0.5, 0.0));
	return ret;
}
float ComplexAbs(ComplexFloat z) {
	return sqrt(z.r * z.r + z.i * z.i);
}
vec3 ComplexAbs(ComplexVec3 z) {
	return sqrt(z.r * z.r + z.i * z.i);
}

ComplexFloat ComplexExp(ComplexFloat z) {
	return ComplexMul(exp(z.r), ComplexFloat(cos(z.i), sin(z.i)));
}
ComplexFloat ComplexLog(ComplexFloat z) {
	//return ComplexFloat(log(sqrt(z.r * z.r + z.i * z.i)), atan(z.i, z.r));
	return ComplexFloat(0.5 * log(z.r * z.r + z.i * z.i), atan(z.i, z.r));
}
ComplexVec3 ComplexLog(ComplexVec3 z) {
	return ComplexVec3(0.5 * log(z.r * z.r + z.i * z.i), atan(z.i, z.r));
}

ComplexFloat ComplexSinh(ComplexFloat z) {
	return ComplexFloat(sinh(z.r) * cos(z.i), cosh(z.r) * sin(z.i));
}
ComplexFloat ComplexCosh(ComplexFloat z) {
	return ComplexFloat(cosh(z.r) * cos(z.i), sinh(z.r) * sin(z.i));
}
ComplexVec3 ComplexCosh(ComplexVec3 z) {
	return ComplexVec3(cosh(z.r) * cos(z.i), sinh(z.r) * sin(z.i));
}
ComplexFloat ComplexTanh(ComplexFloat z) {
	float s = sin(z.i), c = cos(z.i), sh = sinh(z.r), ch = cosh(z.r);
	return ComplexDiv(ComplexFloat(sh*c, ch*s), ComplexFloat(ch*c, sh*s));
}

ComplexFloat ComplexSin(ComplexFloat z) {
	// sin(z) = -i*sinh(i*z)
	z = ComplexSinh(ComplexFloat(-z.i, z.r));
	return ComplexFloat(z.i, -z.r);
}
ComplexFloat ComplexCos(ComplexFloat z) {
	// cos(z) = cosh(i*z)
	return ComplexCosh(ComplexFloat(-z.i, z.r));
}
ComplexVec3 ComplexCos(ComplexVec3 z) {
	// cos(z) = cosh(i*z)
	return ComplexCosh(ComplexVec3(-z.i, z.r));
}
ComplexFloat ComplexTan(ComplexFloat z) {
	// tan(z) = -i*tanh(i*z)
	z = ComplexTanh(ComplexFloat(-z.i, z.r));
	return ComplexFloat(z.i, -z.r);
}

// No idea if these are correct.
// They do appear to be correct for Im(z) == 0, but I have no reference for Im(z) != 0.
ComplexFloat ComplexArcsin(ComplexFloat z) {
	z = ComplexLog(ComplexAdd(ComplexFloat(-z.i, z.r), ComplexSqrt(ComplexSub(1, ComplexMul(z, z)))));
	return ComplexFloat(z.i, -z.r);
}
ComplexVec3 ComplexArcsin(ComplexVec3 z) {
	z = ComplexLog(ComplexAdd(ComplexVec3(-z.i, z.r), ComplexSqrt(ComplexSub(vec3(1), ComplexMul(z, z)))));
	return ComplexVec3(z.i, -z.r);
}
ComplexFloat ComplexArccos(ComplexFloat z) {
	z = ComplexLog(ComplexAdd(ComplexFloat(-z.i, z.r), ComplexSqrt(ComplexSub(1, ComplexMul(z, z)))));
	return ComplexFloat(hpi - z.i, z.r);
}
#endif
