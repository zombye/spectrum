#if !defined INCLUDE_FRAGMENT_RAYTRACER
#define INCLUDE_FRAGMENT_RAYTRACER

//#define RAYTRACER_HQ

bool RaytraceIntersection(inout vec3 position, vec3 startVS, vec3 direction, int steps, int refinements) {
	bool doRefinements = refinements > 0;
	int refinement = 0;

	#ifdef RAYTRACER_HQ
		int refinementIteration = 0;
	#endif

	//*
	vec3 increment  = direction * abs(startVS.z) + startVS;
	     increment  = ViewSpaceToScreenSpace(increment, gbufferProjection) - position;
	     increment *= MinOf((step(0.0, increment) - position) / increment) / steps;
	//*/
	/*
	vec3 clipPlaneIntersection = vec3(direction.xy / direction.z, 1.0) * ((direction.z < 0.0 ? -far : -near) - startVS.z) + startVS;
	     clipPlaneIntersection = ViewSpaceToScreenSpace(clipPlaneIntersection, gbufferProjection);
	vec3 increment  = clipPlaneIntersection - position;
	     increment *= min(MinOf((step(0.0, increment.xy) - position.xy) / increment.xy), 1.0);
	     increment /= steps;
	//*/
	float stepSize = length(increment);

	position += increment;

	for (int i = 0; i < steps; ++i) {
		// Not interpolating seems to give better results
		float depth = texelFetch(depthtex1, ivec2(floor(position.xy * viewResolution)), 0).r;

		if (depth < position.z) {
			if (position.z - depth <= stepSize) {
				if (doRefinements) {
					if (++refinement > refinements) {
						position.z = depth;
						return position.z < 1.0;
					}

					increment /= 2.0;
					stepSize  /= 2.0;
					position  -= increment;
					#ifdef RAYTRACER_HQ
						steps *= 2; i = i * 2 - 1;
						refinementIteration = i;
					#else
						i -= 2;
					#endif

					continue;
				} else {
					position.z = depth;
					return position.z < 1.0;
				}
			}
		}

		#ifdef RAYTRACER_HQ
			if (refinement > 0 && (i - refinementIteration) == 2) {
				increment *= 2.0;
				stepSize  *= 2.0;
				steps /= 2; i /= 2;
				--refinement;
			}
		#endif

		position += increment;
	}

	return false;
}

bool RaytraceIntersection(inout vec3 position, vec3 startVS, vec3 direction, float dither, float range, int steps, int refinements) {
	bool doRefinements = refinements > 0;
	int refinement = 0;

	#ifdef RAYTRACER_HQ
		int refinementIteration = 0;
	#endif

	vec3 increment = direction * (direction.z > 0.0 ? min(-0.5 * startVS.z / direction.z, range) : range) + startVS;
	     increment = (ViewSpaceToScreenSpace(increment, gbufferProjection) - position) / steps;
	float stepSize = length(increment);

	position += increment * dither;

	for (int i = 0; i < steps; ++i) {
		if (Clamp01(position.xy) != position.xy) { break; }

		// Not interpolating seems to give better results
		float depth = texelFetch(depthtex1, ivec2(floor(position.xy * viewResolution)), 0).r;

		if (depth < position.z) {
			if (position.z - depth <= stepSize) {
				if (doRefinements) {
					if (++refinement > refinements) {
						position.z = depth;
						return position.z < 1.0;
					}

					increment /= 2.0;
					stepSize  /= 2.0;
					position  -= increment;
					#ifdef RAYTRACER_HQ
						steps *= 2; i = i * 2 - 1;
						refinementIteration = i;
					#else
						i -= 2;
					#endif

					continue;
				} else {
					position.z = depth;
					return position.z < 1.0;
				}
			}
		}

		#ifdef RAYTRACER_HQ
			if (refinement > 0 && (i - refinementIteration) == 2) {
				increment *= 2.0;
				stepSize  *= 2.0;
				steps /= 2; i /= 2;
				--refinement;
			}
		#endif

		position += increment;
	}

	return false;
}

#endif
