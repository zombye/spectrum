#include "/settings.glsl"

//----------------------------------------------------------------------------//

// Viewport
uniform float viewWidth, viewHeight;

// Time
uniform float frameTimeCounter;

// Positions
uniform vec3 cameraPosition;

// Hand light
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

// Samplers
uniform sampler2D tex;
#ifdef MC_NORMAL_MAP
uniform sampler2D normals;
#endif
#ifdef MC_SPECULAR_MAP
uniform sampler2D specular;
#endif

uniform sampler2D gaux1;
uniform sampler2D gaux4;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform sampler2D shadowtex1;

uniform sampler2D noisetex;

//----------------------------------------------------------------------------//

varying vec4 tint;

varying vec2 baseUV;
varying vec2 lightmap;

varying mat3 tbn;

varying vec2 metadata;

varying mat3 position;

//----------------------------------------------------------------------------//

#include "/lib/util/clamping.glsl"
#include "/lib/util/constants.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/miscellaneous.glsl"
#include "/lib/util/noise.glsl"
#include "/lib/util/packing.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/util/texture.glsl"

float get3DNoise(vec3 pos) {
	float flr = floor(pos.z);
	vec2 coord = (pos.xy * 0.015625) + (flr * 0.265625); // 1/64 | 17/64
	vec2 noise = texture2D(noisetex, coord).xy;
	return mix(noise.x, noise.y, pos.z - flr);
}

#include "/lib/uniform/vectors.glsl"
#include "/lib/uniform/colors.glsl"
#include "/lib/uniform/gbufferMatrices.glsl"
#include "/lib/uniform/shadowMatrices.glsl"

#include "/lib/misc/importanceSampling.glsl"
#include "/lib/misc/shadowDistortion.glsl"

//--//

#include "/lib/fragment/masks.fsh"
#include "/lib/fragment/materials.fsh"

#include "/lib/fragment/water/waves.fsh"
#include "/lib/fragment/water/normal.fsh"

#include "/lib/fragment/sky.fsh"
#include "/lib/fragment/volumetricClouds.fsh"

#include "/lib/fragment/lighting.fsh"

#include "/lib/fragment/raytracer.fsh"
#include "/lib/fragment/specularBRDF.fsh"
#include "/lib/fragment/reflections.fsh"

//--//

void main() {
	vec4 base = texture2D(tex,      baseUV) * tint; if (base.a < 0.102) discard;
	#ifdef MC_NORMAL_MAP
	vec4 norm = texture2D(normals,  baseUV) * 2.0 - 1.0; norm.w = length(norm.xyz); norm.xyz = tbn * norm.xyz / norm.w;
	#else
	vec4 norm = vec4(tbn[2], 1.0);
	#endif
	#ifdef MC_SPECULAR_MAP
	vec4 spec = texture2D(specular, baseUV);
	#else
	vec4 spec = vec4(0.0, 0.0, 0.0, 0.0);
	#endif

	masks mask = calculateMasks(metadata.x);

	if (mask.water) {
		base = vec4(0.0, 0.0, 0.0, 0.15);
		norm.xyz = water_calculateNormal(position[2] + cameraPosition, tbn, normalize(position[1]));
		spec = vec4(pow(0.02, 1.0 / 3.0), 0.0, 0.99, 0.0);
	}

	material mat = calculateMaterial(base.rgb, spec.rb, mask);
	vec3 normal = norm.xyz;

	// kinda hacky
	base.a = mix(base.a, 1.0, f_dielectric(dot(normal, -normalize(position[1])), 1.0, f0ToIOR(mat.reflectance)));

	// Exposure - it needs to be done here for the sun to look right
	float prevLuminance = texture2D(gaux4, vec2(0.5)).r;
	if (prevLuminance == 0.0) prevLuminance = 0.35;

	mat3 pos = mat3(
		vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z),
		position[1],
		position[2]
	);

	vec3 sunVisibility;
	vec3
	composite  = calculateLighting(pos, normal, lightmap, mat, sunVisibility);
	composite *= mat.albedo;
	composite += calculateReflections(pos, normalize(position[1]), normal, mat.reflectance, mat.roughness, lightmap.y) / base.a;
	composite += sunVisibility * shadowLightColor * specularBRDF(-normalize(position[1]), normal, mrp_sphere(reflect(normalize(position[1]), normal), shadowLightVector, sunAngularRadius), mat.reflectance, mat.roughness * mat.roughness) / base.a;

	composite *= 0.35 / prevLuminance;

/* DRAWBUFFERS:2 */

	gl_FragData[0] = vec4(composite, base.a);
}
