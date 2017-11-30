#extension GL_ARB_shader_texture_lod : require
#extension GL_ARB_texture_query_lod : require
#extension GL_EXT_gpu_shader4 : require

#ifdef MC_GL_ARB_texture_gather
#extension GL_ARB_texture_gather : require
#else
vec4 textureGather(sampler2D sampler, vec2 p, int comp) {
	return vec4(
		texelFetch2D(sampler, ivec2((p) * textureSize2D(sampler, 0) + vec2(0,1)), 0)[comp],
		texelFetch2D(sampler, ivec2((p) * textureSize2D(sampler, 0) + vec2(1,1)), 0)[comp],
		texelFetch2D(sampler, ivec2((p) * textureSize2D(sampler, 0) + vec2(1,0)), 0)[comp],
		texelFetch2D(sampler, ivec2((p) * textureSize2D(sampler, 0) + vec2(0,0)), 0)[comp]
	);
}
vec4 textureGather(sampler2D sampler, vec2 p) {
	return textureGather(sampler, p, 0);
}
#endif
