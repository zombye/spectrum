#if !defined INCLUDE_FRAGMENT_RAYTRACER
#define INCLUDE_FRAGMENT_RAYTRACER

#define SSR_DEPTH_LENIENCY 5 // [1 2 5 10 20 50 100 200 500]

float AscribeDepth(float depth, float ascribeAmount) {
	depth = 1.0 - 2.0 * depth;
	depth = (depth + gbufferProjection[2].z * ascribeAmount) / (1.0 + ascribeAmount);
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

	rayStep /= MaxOf(abs(rayStep.xy));

	float ditherp = floor(stride * fract(Bayer8(gl_FragCoord.xy) + frameR1) + 1.0);

	// (Pixel-size) steps to edge of screen or near/far plane along each axis
	vec3 stepsToEnd = (step(0.0, rayStep) * vec3(viewResolution - 1.0, 1.0) - position) / rayStep;
	stepsToEnd.z += float(stride); // Add stride to z, ensures we intersect anything near the far plane
	float tMax = min(MinOf(stepsToEnd), MaxOf(viewResolution));

	vec3 rayOrigin = position;

	float ascribeAmount = SSR_DEPTH_LENIENCY * float(stride) * viewPixelSize.y * gbufferProjectionInverse[1].y;

	bool hit = false;
	float t = ditherp;
	while (t < tMax && !hit) {
		float stepStride = t == ditherp ? ditherp : float(stride);

		// Not enough precision along Z to simply add stepStride * rayStep to position.
		// Might be feasible if depth is reversed.
		position = rayOrigin + t * rayStep;

		// Z at current step & one step towards -Z
		// Using this specifically seems to prevent most false intersections
		float maxZ = position.z;
		float minZ = position.z - stepStride * abs(rayStep.z);

		// Could also check interpolated depth here, would prevent the few remaining possible false intersections.
		float depth = texelFetch(depthtex1, ivec2(position.xy), 0).x;
		float ascribedDepth = AscribeDepth(depth, ascribeAmount);

		// Intersection test
		hit = maxZ >= depth && minZ <= ascribedDepth;

		// Optionally check that depth is < 1 if we don't want to intersect the sky
		//hit = hit && depth < 1.0;

		if (!hit) { t += float(stride); }
	}

	if (hit) {
		// Eventually I want to implement a better algo here.
		// I have an idea for one that might be better, which looks at the bits of stride.
		// From that it then decides how far to step in each direction.
		// For now though this is good enough.

		bool refhit = true;
		float refstride = stride;
		for (int i = 0; i < findMSB(stride); ++i) {
			t += (refhit ? -1.0 : 1.0) * (refstride *= 0.5);
			position = rayOrigin + t * rayStep;

			// Z at current step & one step towards -Z
			// Using this specifically seems to prevent most false intersections
			float maxZ = position.z;
			float minZ = position.z - stride * abs(rayStep.z);

			// Could also check interpolated depth here, would prevent the few remaining possible false intersections.
			float depth = texelFetch(depthtex1, ivec2(position.xy), 0).x;
			float ascribedDepth = AscribeDepth(depth, ascribeAmount);

			// Intersection test
			refhit = maxZ >= depth && minZ <= ascribedDepth;

			// Optionally check that depth is < 1 if we don't want to intersect the sky
			//hit = hit && depth < 1.0;
		}

		/* This is skipped as in some cases it results in excessive flickering with TAA
		if (!refhit) {
			t += 1.0;
			position = rayOrigin + t * rayStep;
		}
		//*/
	}

	position.xy *= viewPixelSize;

	return hit;
}

#endif
