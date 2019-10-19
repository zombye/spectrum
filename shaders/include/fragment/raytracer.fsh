#if !defined INCLUDE_FRAGMENT_RAYTRACER
#define INCLUDE_FRAGMENT_RAYTRACER

float AscribeDepth(float depth, float ascribeAmount) {
	depth = 1.0 - 2.0 * depth;
	depth = (depth - gbufferProjection[2].z) / (1.0 + ascribeAmount) + gbufferProjection[2].z;
	return 0.5 - 0.5 * depth;
}

bool IntersectSSRay(
	inout vec3 position, // Starting position in screen-space. This gets set to the hit position, also in screen-space.
	vec3 startVS, // Starting position in view-space
	vec3 rayDirection, // Ray direction in view-space
	const uint stride // Stride, in pixels. Should be >= 1.
) {
	vec3 rayStep  = startVS + abs(startVS.z) * rayDirection;
	     rayStep  = ViewSpaceToScreenSpace(rayStep, gbufferProjection) - position;
	     rayStep *= MinOf((step(0.0, rayStep) - position) / rayStep);

	position.xy *= viewResolution;
	rayStep.xy *= viewResolution;

	rayStep /= abs(abs(rayStep.x) < abs(rayStep.y) ? rayStep.y : rayStep.x);

	vec2 stepsToEnd = (step(0.0, rayStep.xy) * viewResolution - position.xy) / rayStep.xy;
	uint maxSteps = uint(ceil(min(min(stepsToEnd.x, stepsToEnd.y), MaxOf(viewResolution)) / float(stride)));

	vec3 startPosition = position;

	bool hit = false;
	float ditherp = floor(stride * fract(Bayer8(gl_FragCoord.xy) + fract((phi - 1.0) * frameCounter)) + 1.0);
	for (uint i = 0u; i < maxSteps && !hit; ++i) {
		float pixelSteps = float(i * stride) + ditherp;
		position = startPosition + pixelSteps * rayStep;

		// Z at current step & one step towards -Z
		float maxZ = position.z;
		float minZ = rayStep.z > 0.0 && i == 0u ? startPosition.z : position.z - float(stride) * abs(rayStep.z);

		if (1.0 < minZ || maxZ < 0.0) { break; }

		// Could also check interpolated depth here, would prevent the few remaining possible false intersections.
		float depth = texelFetch(depthtex1, ivec2(position.xy), 0).r;
		float ascribedDepth = AscribeDepth(depth, 5e-3 * (i == 0u ? ditherp : float(stride)) * gbufferProjectionInverse[1].y);

		hit = maxZ >= depth && minZ <= ascribedDepth && depth < 1.0;
	}

	position.xy *= viewPixelSize;

	return hit;
}

#endif
