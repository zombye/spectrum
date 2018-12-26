#if !defined INCLUDE_FRAGMENT_FILMTONEMAP
#define INCLUDE_FRAGMENT_FILMTONEMAP

#define TONEMAP_TOE_STRENGTH      0.1 // [-1.0 -0.99 -0.98 -0.97 -0.96 -0.95 -0.94 -0.93 -0.92 -0.91 -0.9 -0.89 -0.88 -0.87 -0.86 -0.85 -0.84 -0.83 -0.82 -0.81 -0.8 -0.79 -0.78 -0.77 -0.76 -0.75 -0.74 -0.73 -0.72 -0.71 0.7 0.69 -0.68 -0.67 -0.66 -0.64 -0.63 -0.62 -0.61 -0.6 -0.59 -0.58 -0.57 -0.56 -0.55 -0.54 -0.53 -0.52 -0.51 -0.5 -0.49 -0.48 -0.47 -0.46 -0.45 -0.44 -0.43 -0.42 -0.41 -0.4 -0.39 -0.38 -0.37 -0.36 -0.35 -0.34 -0.33 -0.32 -0.31 -0.3 -0.29 -0.28 -0.27 -0.26 -0.25 -0.24 -0.23 -0.22 -0.21 -0.2 -0.19 -0.18 -0.17 -0.16 -0.15 -0.14 -0.13 -0.12 -0.11 -0.1 -0.09 -0.08 -0.07 -0.06 -0.05 -0.04 -0.03 -0.02 -0.01 0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define TONEMAP_TOE_LENGTH        0.2 // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define TONEMAP_SHOULDER_STRENGTH 0.5 // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define TONEMAP_SHOULDER_LENGTH   4.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0]
#define TONEMAP_SHOULDER_ANGLE    0.2 // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]

/*\
 * For details see http://filmicworlds.com/blog/filmic-tonemapping-with-piecewise-power-curves/
 * Note that shoulderStrength here is shoulderLength on that page.
 *
 * Possible future change: Separate settings for each channel.
\*/

#if defined MC_GL_VENDOR_ATI && defined MC_GL_RENDERER_RADEON
	#define const
#endif

//--// Structs

struct UserParameters {
	float toeStrength;
	float toeLength;
	float shoulderStrength;
	float shoulderLength;
	float shoulderAngle;
};

struct SegmentParameters {
	float lnA;
	float B;
	vec2 offset;
	vec2 scale;
};

struct CurveParameters {
	vec2 p0;
	vec2 p1;
	float w;
	vec2 overshoot;
	SegmentParameters[3] segments;
};

//--// Curve evaluation

float EvaluateCurveSegment(float x, const SegmentParameters segment) {
	x = (x - segment.offset.x) * segment.scale.x;
	x = x > 0.0 ? exp(segment.lnA + (segment.B * log(x))) : 0.0;
	return segment.scale.y * x + segment.offset.y;
}
float EvaluateCurveSegmentInv(float y, const SegmentParameters segment) {
	y = (y - segment.offset.y) / segment.scale.y;
	y = y > 0.0 ? exp((log(y) - segment.lnA) / segment.B) : 0.0;
	return (y / segment.scale.x) + segment.offset.x;
}

float EvaluateFullCurve(float x, const CurveParameters curve) {
	int index = x < curve.p0.x ? 0 : (x < curve.p1.x ? 1 : 2);
	return EvaluateCurveSegment(x, curve.segments[index]);
}
float EvaluateFullCurveInv(float y, const CurveParameters curve) {
	int index = y < curve.p0.y ? 0 : (y < curve.p1.y ? 1 : 2);
	return EvaluateCurveSegmentInv(y, curve.segments[index]);
}

//--// Curve paramter derivation (only for reference, these functions are not actually used, instead I derive the parameters with a lot of constants in the main tonemap function)

/*
void SolveAB(vec2 p0, float m, out float lnA, out float B) {
	B = (m * p0.x) / p0.y;
	lnA = log(p0.y) - B * log(p0.x);
}

CurveParameters DeriveCurveParameters(const UserParameters params) {
	CurveParameters curve;

	//--// Toe Params

	// Square toeLength to avoid having to input extremely small values for short toes
	curve.p0.x =  0.5 * params.toeLength * params.toeLength;
	curve.p0.y = (1.0 - params.toeStrength) * curve.p0.x;

	//--// Shoulder Params

	curve.p1 = curve.p0 + (1.0 - params.shoulderStrength) * (1.0 - curve.p0.y);
	curve.w  = curve.p0.x + (1.0 - curve.p0.y) + exp2(params.shoulderLength) - 1.0;

	curve.overshoot.x = 2.0 * curve.w * params.shoulderAngle * params.shoulderLength;
	curve.overshoot.y = 0.5 * params.shoulderAngle * params.shoulderLength;

	//--// Segments

	vec2 dp = curve.p1 - curve.p0;
	float m = dp.y != 0.0 ? dp.y / dp.x : 1.0;

	// Toe segment
	SolveAB(curve.p0, m, curve.segments[0].lnA, curve.segments[0].B);
	curve.segments[0].offset = vec2(0.0);
	curve.segments[0].scale = vec2(1.0);
	// Linear segment
	curve.segments[1].lnA = log(m);
	curve.segments[1].B = 1.0;
	curve.segments[1].offset = vec2(-curve.p0.y / m + curve.p0.x, 0.0);
	curve.segments[1].scale = vec2(1.0);
	// Shoulder segment
	SolveAB(1.0 + curve.overshoot - curve.p1, m, curve.segments[2].lnA, curve.segments[2].B);
	curve.segments[2].offset = 1.0 + curve.overshoot;
	curve.segments[2].scale = vec2(-1.0);

	// Normalize to ensure that when X=W, Y=1
	float invScale = 1.0 / EvaluateCurveSegment(curve.w, curve.segments[2]);
	curve.segments[0].offset.y *= invScale;
	curve.segments[0].scale.y  *= invScale;
	curve.segments[1].offset.y *= invScale;
	curve.segments[1].scale.y  *= invScale;
	curve.segments[2].offset.y *= invScale;
	curve.segments[2].scale.y  *= invScale;

	return curve;
}
//*/

//--// Main tonemap function

vec3 Tonemap(vec3 color) {
	const UserParameters params = UserParameters(TONEMAP_TOE_STRENGTH, TONEMAP_TOE_LENGTH, TONEMAP_SHOULDER_STRENGTH, TONEMAP_SHOULDER_LENGTH, TONEMAP_SHOULDER_ANGLE);

	//--// Derive curve

	// Square toeLength to avoid having to input extremely small values for short toes
	const vec2 p0 = vec2(0.5 * params.toeLength * params.toeLength, (1.0 - params.toeStrength) * 0.5 * params.toeLength * params.toeLength);
	const vec2 p1 = p0 + (1.0 - params.shoulderStrength) * (1.0 - p0.y);
	const float w = p0.x + (1.0 - p0.y) + exp2(params.shoulderLength) - 1.0;
	const vec2 overshoot = vec2(2.0 * w * params.shoulderAngle * params.shoulderLength, 0.5 * params.shoulderAngle * params.shoulderLength);

	const vec2 dp = p1 - p0;
	const float m = dp.y != 0.0 ? dp.y / dp.x : 1.0;

	const SegmentParameters toeSegment = SegmentParameters(log(p0.y) - (m * p0.x / p0.y) * log(p0.x), m * p0.x / p0.y, vec2(0.0), vec2(1.0));
	const SegmentParameters linearSegment = SegmentParameters(log(m), 1.0, vec2(-p0.y / m + p0.x, 0.0), vec2(1.0));
	const vec2 p1s = 1.0 + overshoot - p1;
	const SegmentParameters shoulderSegment = SegmentParameters(log(p1s.y) - (m * p1s.x / p1s.y) * log(p1s.x), m * p1s.x / p1s.y, 1.0 + overshoot, vec2(-1.0));

	const SegmentParameters[3] segments = SegmentParameters[3](toeSegment, linearSegment, shoulderSegment);

	// Normalize to ensure that when X=W, Y=1
	const float invScale = 1.0 / (-(segments[2].offset.x - w > 0.0 ? exp(segments[2].lnA + (segments[2].B * log(segments[2].offset.x - w))) : 0.0) + segments[2].offset.y);

	const SegmentParameters[3] normSegments = SegmentParameters[3](
		SegmentParameters(segments[0].lnA, segments[0].B, segments[0].offset * vec2(1.0, invScale), segments[0].scale * vec2(1.0, invScale)),
		SegmentParameters(segments[1].lnA, segments[1].B, segments[1].offset * vec2(1.0, invScale), segments[1].scale * vec2(1.0, invScale)),
		SegmentParameters(segments[2].lnA, segments[2].B, segments[2].offset * vec2(1.0, invScale), segments[2].scale * vec2(1.0, invScale))
	);

	const CurveParameters curve = CurveParameters(p0, p1, w, overshoot, normSegments);

	//--// Apply curve

	// This messes with the white point, but it fixes the brightness.
	color /= invScale;

	color.r = EvaluateFullCurve(color.r, curve);
	color.g = EvaluateFullCurve(color.g, curve);
	color.b = EvaluateFullCurve(color.b, curve);

	return color;
}
vec3 TonemapInv(vec3 color) {
	const UserParameters params = UserParameters(TONEMAP_TOE_STRENGTH, TONEMAP_TOE_LENGTH, TONEMAP_SHOULDER_STRENGTH, TONEMAP_SHOULDER_LENGTH, TONEMAP_SHOULDER_ANGLE);

	//--// Derive curve

	// Square toeLength to avoid having to input extremely small values for short toes
	const vec2 p0 = vec2(0.5 * params.toeLength * params.toeLength, (1.0 - params.toeStrength) * 0.5 * params.toeLength * params.toeLength);
	const vec2 p1 = p0 + (1.0 - params.shoulderStrength) * (1.0 - p0.y);
	const float w = p0.x + (1.0 - p0.y) + exp2(params.shoulderLength) - 1.0;
	const vec2 overshoot = vec2(2.0 * w * params.shoulderAngle * params.shoulderLength, 0.5 * params.shoulderAngle * params.shoulderLength);

	const vec2 dp = p1 - p0;
	const float m = dp.y != 0.0 ? dp.y / dp.x : 1.0;

	const SegmentParameters toeSegment = SegmentParameters(log(p0.y) - (m * p0.x / p0.y) * log(p0.x), m * p0.x / p0.y, vec2(0.0), vec2(1.0));
	const SegmentParameters linearSegment = SegmentParameters(log(m), 1.0, vec2(-p0.y / m + p0.x, 0.0), vec2(1.0));
	const vec2 p1s = 1.0 + overshoot - p1;
	const SegmentParameters shoulderSegment = SegmentParameters(log(p1s.y) - (m * p1s.x / p1s.y) * log(p1s.x), m * p1s.x / p1s.y, 1.0 + overshoot, vec2(-1.0));

	const SegmentParameters[3] segments = SegmentParameters[3](toeSegment, linearSegment, shoulderSegment);

	// Normalize to ensure that when X=W, Y=1
	const float invScale = 1.0 / (-(segments[2].offset.x - w > 0.0 ? exp(segments[2].lnA + (segments[2].B * log(segments[2].offset.x - w))) : 0.0) + segments[2].offset.y);

	const SegmentParameters[3] normSegments = SegmentParameters[3](
		SegmentParameters(segments[0].lnA, segments[0].B, segments[0].offset * vec2(1.0, invScale), segments[0].scale * vec2(1.0, invScale)),
		SegmentParameters(segments[1].lnA, segments[1].B, segments[1].offset * vec2(1.0, invScale), segments[1].scale * vec2(1.0, invScale)),
		SegmentParameters(segments[2].lnA, segments[2].B, segments[2].offset * vec2(1.0, invScale), segments[2].scale * vec2(1.0, invScale))
	);

	const CurveParameters curve = CurveParameters(p0, p1, w, overshoot, normSegments);

	//--// Apply curve

	color.r = EvaluateFullCurveInv(color.r, curve);
	color.g = EvaluateFullCurveInv(color.g, curve);
	color.b = EvaluateFullCurveInv(color.b, curve);

	color *= invScale;

	return color;
}

#if defined MC_GL_VENDOR_ATI && defined MC_GL_RENDERER_RADEON
	#undef const
#endif

#endif
