#if !defined INCLUDE_SHARED_SHADOWDISTORTION
#define INCLUDE_SHARED_SHADOWDISTORTION

float CalculateDistortionFactor(vec2 position) {
	#ifdef SHADOW_INFINITE_RENDER_DISTANCE
		return 1.0 / (SHADOW_DISTORTION_AMOUNT_INVERSE + length(position));
	#else
		return 1.0 / (SHADOW_DISTORTION_AMOUNT_INVERSE + (1.0 - SHADOW_DISTORTION_AMOUNT_INVERSE) * length(position));
	#endif
}

vec2 DistortShadowSpace(vec2 position) {
	return position * CalculateDistortionFactor(position);
}
vec3 DistortShadowSpace(vec3 position) {
	position.xy = DistortShadowSpace(position.xy);
	return position;
}

#endif
