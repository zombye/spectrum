#if !defined INCLUDE_SHARED_HEADER
#define INCLUDE_SHARED_HEADER

// This is defined so that OptiFine detects them.
#define attribute in

//--// Extensions

// Fastest way to do what it does, but not required.
#ifdef MC_GL_ARB_texture_gather
	#extension GL_ARB_texture_gather : enable
#else
	vec4 textureGather(sampler2D sampler, vec2 coord) {
		ivec2 res = textureSize(sampler, 0);
		ivec2 iCoord = ivec2(coord * res);

		return vec4(
			texelFetch(sampler, (iCoord + ivec2(0, 1)) % res, 0).r,
			texelFetch(sampler, (iCoord + ivec2(1, 1)) % res, 0).r,
			texelFetch(sampler, (iCoord + ivec2(1, 0)) % res, 0).r,
			texelFetch(sampler, (iCoord + ivec2(0, 0)) % res, 0).r
		);
	}
#endif

#endif
