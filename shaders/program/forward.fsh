#include "/settings.glsl"

const bool gaux3MipmapEnabled = true;

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

uniform sampler2D gaux3; // composite
uniform sampler2D gaux4; // temporal

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

varying vec3 positionView;
varying vec3 positionScene;

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

float get3DNoise(vec3 position) {
	float flr = floor(position.z);
	vec2 coord = (position.xy * 0.015625) + (flr * 0.265625); // 1/64 | 17/64
	vec2 noise = texture2D(noisetex, coord).xy;
	return mix(noise.x, noise.y, position.z - flr);
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

	mat3 position = mat3(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z), positionView, positionScene);

	if (mask.water) {
		base = vec4(0.02, 0.03, 0.06, 0.15);
		norm.xyz = water_calculateNormal(position[2] + cameraPosition, tbn, normalize(position[1]));
		spec = vec4(pow(0.02, 1.0 / 3.0), 0.0, 0.995, 0.0);
	}

	material mat = calculateMaterial(base.rgb, spec.rb, mask);
	vec3 normal = norm.xyz;

	// kinda hacky
	base.a = mix(base.a, 1.0, f_dielectric(max0(dot(normal, -normalize(position[1]))), 1.0, f0ToIOR(mat.reflectance)));

	vec3 sunVisibility;
	vec3 diffuse   = calculateLighting(position, normal, lightmap, mat, sunVisibility) * mat.albedo;
	vec3 specular  = calculateReflections(position, normalize(position[1]), normal, mat.reflectance, mat.roughness, lightmap.y, sunVisibility) / base.a;
	vec3 composite = blendMaterial(diffuse, specular, mat);

	float prevLuminance = texture2D(gaux4, position[0].st).r;
	if (prevLuminance == 0.0) prevLuminance = 0.35;
	composite *= EXPOSURE / prevLuminance;

/* DRAWBUFFERS:45 */

	gl_FragData[0] = vec4(composite, base.a);
	gl_FragData[1] = vec4(packNormal(norm.xyz), pack2x8(vec2(metadata.x / 255.0, lightmap.y)), 1.0);
}