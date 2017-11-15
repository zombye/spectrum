#include "/settings.glsl"

//----------------------------------------------------------------------------//

uniform ivec2 atlasSize;

// Samplers
uniform sampler2D tex;
#if PROGRAM != PROGRAM_ENTITIES && PROGRAM != PROGRAM_HAND && defined MC_NORMAL_MAP
uniform sampler2D normals;
#endif
#ifdef MC_SPECULAR_MAP
uniform sampler2D specular;
#endif

//----------------------------------------------------------------------------//

varying vec4 tint;

varying vec2 baseUV;
varying vec2 lightmap;

varying mat3 tbn;

varying vec2 metadata;

varying vec3 positionView;

//----------------------------------------------------------------------------//

#include "/lib/debug.glsl"

#include "/lib/util/clamping.glsl"
#include "/lib/util/packing.glsl"

#include "/lib/fragment/directionalLightmap.fsh"
#include "/lib/fragment/terrainParallax.fsh"

void main() {
	vec2 parallaxUV = calculateParallaxedUV(baseUV, normalize(positionView * tbn));

	vec4 base = texture2D(tex,      parallaxUV) * tint; if (base.a < 0.102) discard;
	#if PROGRAM != PROGRAM_ENTITIES && PROGRAM != PROGRAM_HAND && defined MC_NORMAL_MAP 
	vec4 norm = texture2D(normals,  parallaxUV) * 2.0 - 1.0; norm.w = length(norm.xyz); norm.xyz = tbn * norm.xyz / norm.w;
	#else
	vec4 norm = vec4(tbn[2], 1.0);
	#endif
	#ifdef MC_SPECULAR_MAP
	vec4 spec = texture2D(specular, parallaxUV);
	#else
	vec4 spec = vec4(0.0, 0.0, 0.0, 0.0);
	#endif

/* DRAWBUFFERS:0127 */

	vec2 outputLightmap = directionalLightmap(lightmap, norm.xyz);

	gl_FragData[0] = vec4(base.rgb, 1.0);
	gl_FragData[1] = vec4(spec.rgb, 1.0);
	gl_FragData[2] = vec4(packNormal(norm.xyz), outputLightmap.x, 1.0);
	gl_FragData[3] = vec4(pack2x8(vec2(metadata.x / 255.0, spec.a)), outputLightmap.y, 0.0, 1.0);

	exit();
}
